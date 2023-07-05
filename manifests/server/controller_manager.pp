# @summary Installs and configures a Kubernetes controller manager
class k8s::server::controller_manager (
  K8s::Ensure $ensure = $k8s::server::ensure,

  Stdlib::HTTPUrl $control_plane_url = $k8s::control_plane_url,

  Hash[String, Data] $arguments = {},

  K8s::CIDR $service_cluster_cidr = $k8s::service_cluster_cidr,
  K8s::CIDR $cluster_cidr         = $k8s::cluster_cidr,

  Stdlib::Unixpath $cert_path = $k8s::server::tls::cert_path,
  Stdlib::Unixpath $ca_cert   = $k8s::server::tls::ca_cert,
  Stdlib::Unixpath $ca_key    = $k8s::server::tls::ca_key,
  Stdlib::Unixpath $cert      = "${cert_path}/kube-controller-manager.pem",
  Stdlib::Unixpath $key       = "${cert_path}/kube-controller-manager.key",

  String[1] $container_registry            = $k8s::container_registry,
  String[1] $container_image               = 'kube-controller-manager',
  Optional[String[1]] $container_image_tag = $k8s::container_image_tag,
) {
  assert_private()

  k8s::binary { 'kube-controller-manager':
    ensure => $ensure,
  }
  $_kubeconfig = '/srv/kubernetes/kube-controller-manager.kubeconf'

  if $k8s::packaging != 'container' {
    $_addn_args = {
      kubeconfig => $_kubeconfig,
    }
  } else {
    $_addn_args = {}
  }

  # For container;
  # use_service_account_credentials => true,
  $_args = k8s::format_arguments({
      allocate_node_cidrs              => true,
      controllers                      => [
        '*',
        'bootstrapsigner',
        'tokencleaner',
      ],
      cluster_cidr                     => $cluster_cidr,
      service_cluster_ip_range         => $service_cluster_cidr,
      cluster_signing_cert_file        => $ca_cert,
      cluster_signing_key_file         => $ca_key,
      leader_elect                     => true,
      root_ca_file                     => $ca_cert,
      service_account_private_key_file => "${cert_path}/service-account.key",
  } + $_addn_args + $arguments)

  if $k8s::packaging == 'container' {
    fail('Not implemented yet')
    $_image = "${container_registry}/${container_image}:${pick($container_image_tag, "v${k8s::version}")}"
    kubectl_apply { 'kube-controller-manager':
      kubeconfig  => '/root/.kube/config',
      api_version => 'apps/v1',
      kind        => 'Deployment',
      namespace   => 'kube-system',
      content     => {},
    }
  } else {
    kubeconfig { $_kubeconfig:
      ensure          => $ensure,
      owner           => $k8s::user,
      group           => $k8s::group,
      server          => $control_plane_url,
      current_context => 'default',

      ca_cert         => $ca_cert,
      client_cert     => $cert,
      client_key      => $key,
    }

    $_sysconfig_path = pick($k8s::sysconfig_path, '/etc/sysconfig')
    file { "${_sysconfig_path}/kube-controller-manager":
      content => epp('k8s/sysconfig.epp', {
          comment               => 'Kubernetes Controller Manager configuration',
          environment_variables => {
            'KUBE_CONTROLLER_MANAGER_ARGS' => $_args.join(' '),
          },
      }),
      notify  => Service['kube-controller-manager'],
    }
    systemd::unit_file { 'kube-controller-manager.service':
      ensure  => $ensure,
      content => epp('k8s/service.epp', {
          name  => 'kube-controller-manager',

          desc  => 'Kubernetes Controller Manager',
          doc   => 'https://github.com/GoogleCloudPlatform/kubernetes',

          dir   => '/srv/kubernetes',
          bin   => 'kube-controller-manager',
          needs => ['kube-apiserver.service'],
          user  => $k8s::user,
          group => $k8s::group,
      }),
      require => [
        File["${_sysconfig_path}/kube-controller-manager"],
        User[$k8s::user],
      ],
      notify  => Service['kube-controller-manager'],
    }
    service { 'kube-controller-manager':
      ensure    => stdlib::ensure($ensure, 'service'),
      enable    => true,
      subscribe => K8s::Binary['kube-controller-manager'],
    }
  }
}
