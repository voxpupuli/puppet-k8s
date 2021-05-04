class k8s::node::kubelet(
  Enum['present', 'absent'] $ensure = $k8s::node::ensure,

  Stdlib::HTTPUrl $master = $k8s::node::master,

  Hash[String, Data] $config = {},
  Hash[String, Data] $arguments = {},
  String $runtime = $k8s::container_manager,
  String $runtime_service = $k8s::container_runtime_service,

  Enum['cert', 'token', 'bootstrap'] $auth = $k8s::node::node_auth,
  Boolean $rotate_server_tls = $auth == 'bootstrap',

  Stdlib::Unixpath $cert_path = $k8s::node::cert_path,
  Stdlib::Unixpath $kubeconfig = '/srv/kubernetes/kubelet.kubeconf',

  # For cert auth
  Optional[Stdlib::Unixpath] $ca_cert = $k8s::node::ca_cert,
  Optional[Stdlib::Unixpath] $cert = $k8s::node::node_cert,
  Optional[Stdlib::Unixpath] $key = $k8s::node::node_key,

  # For token and bootstrap auth
  Optional[Stdlib::Unixpath] $token = $k8s::node::node_token,
) {
  assert_private()

  k8s::binary { 'kubelet':
    ensure    => $ensure,
  }

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
      kubeconfig { $kubeconfig:
        ensure => $ensure,
        server => $master,
        token  => $token,
      }
    }
    'cert': {
      kubeconfig { $kubeconfig:
        ensure      => $ensure,
        server      => $master,

        ca_cert     => $ca_cert,
        client_cert => $cert,
        client_key  => $key,
      }
    }
    default: {
    }
  }

  $config_hash = {
    'apiVersion'         => 'kubelet.config.k8s.io/v1beta1',
    'kind'               => 'KubeletConfiguration',

    'staticPodPath'      => '/etc/kubernetes/manifests',
    'tlsCertFile'        => $cert,
    'tlsPrivateKeyFile'  => $key,
    'rotateCertificates' => $auth == 'bootstrap',
    'serverTLSBootstrap' => $rotate_server_tls,
    'clusterDomain'      => $k8s::cluster_domain,
    'cgroupDriver'       => 'systemd',
  }

  file { '/etc/modules-load.d/k8s':
    ensure  => $ensure,
    content => @(EOF),
    overlay
    br_netfilter
    |- EOF
  }
  exec {
    default:
      path        => ['/bin', '/sbin', '/usr/bin'],
      refreshonly => true,
      subscribe   => File['/etc/modules-load.d/k8s'];

    'modprobe overlay':
      unless => 'lsmod | grep overlay';

    'modprobe br_netfilter':
      unless => 'lsmod | grep overlay';
  }

  file { '/etc/sysctl.d/99-k8s.conf':
    ensure  => $ensure,
    content => @(EOF),
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    |- EOF
  }
  exec { 'sysctl --system':
    path        => ['/sbin', '/usr/sbin'],
    refreshonly => true,
    subscribe   => File['/etc/sysctl.d/99-k8s.conf'],
  }

  file { '/etc/kubernetes/kubelet.conf':
    ensure  => $ensure,
    content => to_yaml($config_hash + $config),
    owner   => 'kube',
    group   => 'kube',
  }

  if $runtime == 'crio' {
    $_runtime_endpoint = 'unix:///var/run/crio/crio.sock'
  } else {
    $_runtime_endpoint = undef
  }

  $_args = k8s::format_arguments({
      config                     => '/etc/kubernetes/kubelet.conf',
      kubeconfig                 => $kubeconfig,
      bootstrap_kubeconfig       => $_bootstrap_kubeconfig,
      cert_dir                   => $cert_path,
      container_runtime_endpoint => $_runtime_endpoint,
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

  systemd::unit_file { 'kubelet.service':
    ensure  => $ensure,
    content => epp('k8s/service.epp', {
      name  => 'kubelet',

      desc  => 'Kubernetes Kubelet Server',
      doc   => 'https://github.com/GoogleCloudPlatform/kubernetes',
      needs => [
        $runtime_service
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
