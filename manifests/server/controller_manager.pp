class k8s::server::controller_manager(
  Enum['present', 'absent'] $ensure = $k8s::ensure,

  Stdlib::HTTPUrl $master = $k8s::node::master,

  Hash[String, Data] $arguments = {},

  Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR] $service_cluster_cidr = $k8s::service_cluster_cidr,
  Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR] $cluster_cidr = $k8s::cluster_cidr,

  Stdlib::Unixpath $cert_path = $k8s::server::tls::cert_path,
  Stdlib::Unixpath $ca_cert = $k8s::server::tls::ca_cert,
  Stdlib::Unixpath $ca_key = $k8s::server::tls::ca_key,
  Stdlib::Unixpath $cert = "${cert_path}/kube-controller-manager.pem",
  Stdlib::Unixpath $key = "${cert_path}/kube-controller-manager.key",
) {
  k8s::binary { 'kube-controller-manager':
    ensure => $ensure,
  }

  $kubeconfig = '/srv/kubernetes/kube-controller-manager.kubeconf'
  kubeconfig { $kubeconfig:
    ensure      => $ensure,
    server      => $master,

    ca_cert     => $ca_cert,
    client_cert => $cert,
    client_key  => $key,
  }

  # For container;
  # use_service_account_credentials => true,
  $args = k8s::format_arguments({
      kubeconfig                       => $kubeconfig,
      allocate_node_cidr               => true,
      cluster_cidr                     => $cluster_cidr,
      service_cluster_ip_range         => $service_cluster_cidr,
      cluster_signing_cert_file        => $ca_cert,
      cluster_signing_key_file         => $ca_key,
      leader_elect                     => true,
      root_ca_file                     => $ca_cert,
      service_account_private_key_file => "${cert_path}/service-account.key",
  } + $arguments)

  if $packaging == 'container' {
    fail('Not implemented yet')
    $_kubeconfig = '/root/.kube/config',
    $_image = "${k8s::container_registry}/${k8s::container_image}:${pick($k8s::container_image_tag, $k8s::version)}"
    kubectl_apply { 'kube-controller-manager':
      kubeconfig  => $_kubeconfig,
      api_version => 'apps/v1',
      kind        => 'Deployment',
      namespace   => 'kube-system',
      content     => {},
    }
  } else {
    file { '/etc/sysconfig/k8s-controller-manager':
      content => epp('k8s/sysconfig.epp', {
          comment               => 'Kubernetes Controller Manager configuration',
          environment_variables => {
            'K8S_CONTROLLER_MANAGER_ARGS' => $_args.join(' '),
          },
      }),
      notify  => Service['k8s-controller-manager'],
    }
    systemd::unit_file { 'k8s-controller-manager.service':
      ensure  => $ensure,
      content => epp('k8s/service.epp', {
        name  => 'k8s-controller-manager',

        desc  => 'Kubernetes Controller Manager',
        doc   => 'https://github.com/GoogleCloudPlatform/kubernetes',

        dir   => '/srv/kubernetes',
        bin   => 'kube-controller-manager',
        needs => ['k8s-apiserver.service'],
        user  => kube,
        group => kube,
      }),
      require => [
        File['/etc/sysconfig/k8s-scheduler'],
        User['kube'],
      ],
      notify  => Service['k8s-controller-manager'],
    }
    service { 'k8s-controller-manager':
      ensure => stdlib::ensure($ensure, 'service'),
      enable => true,
    }
  }
}
