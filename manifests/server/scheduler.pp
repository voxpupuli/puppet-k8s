# @summary Installs and configures a Kubernetes scheduler
class k8s::server::scheduler (
  K8s::Ensure $ensure = $k8s::server::ensure,

  Stdlib::HTTPUrl $control_plane_url = $k8s::control_plane_url,

  Hash[String, Data] $arguments = {},

  Stdlib::Unixpath $cert_path = $k8s::server::tls::cert_path,
  Stdlib::Unixpath $ca_cert   = $k8s::server::tls::ca_cert,
  Stdlib::Unixpath $cert      = "${cert_path}/kube-scheduler.pem",
  Stdlib::Unixpath $key       = "${cert_path}/kube-scheduler.key",

  String[1] $container_registry            = $k8s::container_registry,
  String[1] $container_image               = 'kube-scheduler',
  Optional[String[1]] $container_image_tag = $k8s::container_image_tag,
) {
  assert_private()

  k8s::binary { 'kube-scheduler':
    ensure => $ensure,
  }

  $_kubeconfig = '/srv/kubernetes/kube-scheduler.kubeconf'
  if $k8s::packaging != 'container' {
    $_addn_args = {
      kubeconfig => $_kubeconfig,
    }
  } else {
    $_addn_args = {}
  }

  $_args = k8s::format_arguments({
      leader_elect => true,
  } + $_addn_args + $arguments)

  if $k8s::packaging == 'container' {
    fail('Not implemented yet')
    $_image = "${container_registry}/${container_image}:${pick($container_image_tag, "v${k8s::version}")}"
    kubectl_apply { 'kube-scheduler':
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
    file { "${_sysconfig_path}/kube-scheduler":
      content => epp('k8s/sysconfig.epp', {
          comment               => 'Kubernetes Scheduler configuration',
          environment_variables => {
            'KUBE_SCHEDULER_ARGS' => $_args.join(' '),
          },
      }),
      notify  => Service['kube-scheduler'],
    }
    systemd::unit_file { 'kube-scheduler.service':
      ensure  => $ensure,
      content => epp('k8s/service.epp', {
          name  => 'kube-scheduler',

          desc  => 'Kubernetes Scheduler',
          doc   => 'https://github.com/GoogleCloudPlatform/kubernetes',

          dir   => '/srv/kubernetes',
          bin   => 'kube-scheduler',
          needs => ['kube-apiserver.service'],
          user  => $k8s::user,
          group => $k8s::group,
      }),
      require => [
        File["${_sysconfig_path}/kube-scheduler"],
        User[$k8s::user],
      ],
      notify  => Service['kube-scheduler'],
    }
    service { 'kube-scheduler':
      ensure    => stdlib::ensure($ensure, 'service'),
      enable    => true,
      subscribe => K8s::Binary['kube-scheduler'],
    }
  }
}
