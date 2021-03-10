class k8s::node::kubelet(
  Enum['present', 'absent'] $ensure = $k8s::node::ensure,

  Stdlib::HTTPUrl $master = $k8s::node::master,

  Hash[String, Data] $addn_config = {},
  Array[String] $addn_args = [],

  Enum['cert', 'token', 'bootstrap'] $auth = $k8s::node::node_auth,

  # For cert auth
  Optional[Stdlib::Unixpath] $ca_cert = k8s::node::ca_cert,
  Optional[Stdlib::Unixpath] $cert = k8s::node::node_cert,
  Optional[Stdlib::Unixpath] $key = k8s::node::node_key,

  # For token and bootstrap auth
  Optional[Stdlib::Unixpath] $token = k8s::node::node_token,
) {
  k8s::binary { 'kubelet':
    ensure    => $ensure,
  }

  case $auth {
    'bootstrap': {
      kubeconfig { '/srv/kubernetes/bootstrap-kubelet.kubeconf':
        ensure          => $ensure,
        server          => $master,
        token           => $token,
        skip_tls_verify => true,
      }
      $_rotate_cert = true
    }
    'token': {
      kubeconfig { '/srv/kubernetes/kubelet.kubeconf':
        ensure => $ensure,
        server => $master,
        token  => $token,
      }
      $_rotate_cert = false
    }
    'cert': {
      kubeconfig { '/srv/kubernetes/kubelet.kubeconf':
        ensure      => $ensure,
        server      => $master,

        ca_cert     => $ca_cert,
        client_cert => $cert,
        client_key  => $key,
      }
      $_rotate_cert = false
    }
    default: {}
  }

  $config_hash = {
    'apiVersion'         => 'kubelet.config.k8s.io/v1beta1',
    'kind'               => 'KubeletConfiguration',

    'staticPodPath'      => '/etc/kubernetes/manifests',
    'tlsCertFile'        => $cert,
    'tlsPrivateKeyFile'  => $key,
    'rotateCertificates' => $_rotate_cert,
    'serverTLSBootstrap' => $auth == 'bootstrap',
    'clusterDomain'      => $k8s::cluster_domain,
    'cgroupDriver'       => 'systemd',
  }

  file { '/etc/kubernetes/kubelet.conf':
    ensure  => $ensure,
    content => to_yaml($config_hash + $addn_config),
    owner   => 'kube',
    group   => 'kube',
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
      args  => [ '--config=/etc/kubernetes/kubelet.conf' ] + $addn_args,
    }),
    require => [
      File['/etc/kubernetes/kubelet.conf'],
      User['kube'],
    ],
    notify  => Service['kubelet'],
  }
  $_service_ensure = $ensure ? {
    present => 'running',
    default => 'stopped',
  }
  $_service_enable = $ensure ? {
    present => true,
    default => false,
  }
  service { 'kubelet':
    ensure => $_service_ensure,
    enable => $_service_enable,
  }
}
