class k8s::server::scheduler(
  Enum['present', 'absent'] $ensure = $k8s::server::ensure,

  Stdlib::HTTPUrl $master = $k8s::master,

  Hash[String, Data] $arguments = {},

  Stdlib::Unixpath $cert_path = $k8s::server::tls::cert_path,
  Stdlib::Unixpath $ca_cert = $k8s::server::tls::ca_cert,
  Stdlib::Unixpath $cert = "${cert_path}/kube-scheduler.pem",
  Stdlib::Unixpath $key = "${cert_path}/kube-scheduler.key",
) {
  assert_private()

  k8s::binary { 'kube-scheduler':
    ensure => $ensure,
  }

  $_kubeconfig = '/srv/kubernetes/k8s-scheduler.kubeconf'
  if $k8s::packaging != 'container' {
    $_addn_args = {
      kubeconfig => $_kubeconfig
    }
  } else {
    $_addn_args = { }
  }

  $_args = k8s::format_arguments({
      leader_elect => true,
  } + $_addn_args + $arguments)

  if $k8s::packaging == 'container' {
    fail('Not implemented yet')
    $_image = "${k8s::container_registry}/${k8s::container_image}:${pick($k8s::container_image_tag, $k8s::version)}"
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
      owner           => 'kube',
      group           => 'kube',
      server          => $master,
      current_context => 'default',

      ca_cert         => $ca_cert,
      client_cert     => $cert,
      client_key      => $key,
    }
    file { '/etc/sysconfig/k8s-scheduler':
      content => epp('k8s/sysconfig.epp', {
          comment               => 'Kubernetes Scheduler configuration',
          environment_variables => {
            'K8S_SCHEDULER_ARGS' => $_args.join(' '),
          },
      }),
      notify  => Service['k8s-scheduler'],
    }
    systemd::unit_file { 'k8s-scheduler.service':
      ensure  => $ensure,
      content => epp('k8s/service.epp', {
        name  => 'k8s-scheduler',

        desc  => 'Kubernetes Scheduler',
        doc   => 'https://github.com/GoogleCloudPlatform/kubernetes',

        dir   => '/srv/kubernetes',
        bin   => 'kube-scheduler',
        needs => ['k8s-apiserver.service'],
        user  => kube,
        group => kube,
      }),
      require => [
        File['/etc/sysconfig/k8s-scheduler'],
        User['kube'],
      ],
      notify  => Service['k8s-scheduler'],
    }
    service { 'k8s-scheduler':
      ensure => stdlib::ensure($ensure, 'service'),
      enable => true,
    }
  }
}
