class k8s::node::kubelet(
  Enum['present', 'absent'] $ensure = lookup('k8s::node::ensure', 'k8s::ensure'),

  Stdlib::HTTPUrl $master = lookup('k8s::node::master', 'k8s::master'),

  Hash[String, Data] $config = {},
  Hash[String, Data] $arguments = {},

  Enum['cert', 'token', 'bootstrap'] $auth = lookup('k8s::node::node_auth'),

  Stdlib::Unixpath $cert_path = $k8s::node::cert_path,

  # For cert auth
  Optional[Stdlib::Unixpath] $ca_cert = lookup('k8s::node::ca_cert'),
  Optional[Stdlib::Unixpath] $cert = lookup('k8s::node::node_cert'),
  Optional[Stdlib::Unixpath] $key = lookup('k8s::node::node_key'),

  # For token and bootstrap auth
  Optional[Stdlib::Unixpath] $token = lookup('k8s::node::node_token'),
) {
  include k8s::node

  k8s::binary { 'kubelet':
    ensure    => $ensure,
  }

  $_kubeconfig = '/srv/kubernetes/kubelet.kubeconf'
  if $auth == 'bootstrap' {
    $_bootstrap_kubeconfig = '/srv/kubernetes/bootstrap-kubelet.kubeconf'
  } else {
    $_bootstrap_kubeconfig = undef
  }

  case $auth {
    'bootstrap': {
      kubeconfig { $_bootstrap_kubeconfig:
        ensure          => $ensure,
        server          => $master,
        token           => $token,
        skip_tls_verify => true,
      }
    }
    'token': {
      kubeconfig { $_kubeconfig:
        ensure => $ensure,
        server => $master,
        token  => $token,
      }
    }
    'cert': {
      kubeconfig { $_kubeconfig:
        ensure      => $ensure,
        server      => $master,

        ca_cert     => $ca_cert,
        client_cert => $cert,
        client_key  => $key,
      }
    }
    default: { }
  }

  $config_hash = {
    'apiVersion'         => 'kubelet.config.k8s.io/v1beta1',
    'kind'               => 'KubeletConfiguration',

    'staticPodPath'      => '/etc/kubernetes/manifests',
    'tlsCertFile'        => $cert,
    'tlsPrivateKeyFile'  => $key,
    'rotateCertificates' => $auth == 'bootstrap',
    'serverTLSBootstrap' => $auth == 'bootstrap',
    'clusterDomain'      => $k8s::cluster_domain,
    'cgroupDriver'       => 'systemd',
  }

  file { '/etc/kubernetes/kubelet.conf':
    ensure  => $ensure,
    content => to_yaml($config_hash + $config),
    owner   => 'kube',
    group   => 'kube',
  }

  $_args = k8s::format_arguments({
      config               => '/etc/kubernetes/kubelet.conf',
      kubeconfig           => $_kubeconfig,
      bootstrap_kubeconfig => $_bootstrap_kubeconfig,
      cert_dir             => $cert_path,
  } + $arguments)

  file { '/etc/sysconfig/kubelet':
    content => epp('k8s/sysconfig.epp', {
        comment               => 'Kubernetes Kubelet configuration',
        environment_variables => {
          'KUBELET_ARGS' => $_args.join(' '),
        },
    }),
    notify  => Service['kubelet'],
  }

  $runtime = 'crio.service'
  systemd::unit_file { 'kubelet.service':
    ensure  => $ensure,
    content => epp('k8s/service.epp', {
      name  => 'kubelet',

      desc  => 'Kubernetes Kubelet Server',
      doc   => 'https://github.com/GoogleCloudPlatform/kubernetes',
      needs => [
        $runtime
      ],

      dir   => '/var/lib/kubelet',
      bin   => 'kubelet',
      user  => kube,
      group => kube,
    }),
    require => [
      File['/etc/sysconfig/kubelet', '/etc/kubernetes/kubelet.conf'],
      User['kube'],
    ],
    notify  => Service['kubelet'],
  }
  service { 'kubelet':
    ensure => stdlib::ensure($ensure, 'service'),
    enable => true,
  }
}
