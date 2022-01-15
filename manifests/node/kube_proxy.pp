class k8s::node::kube_proxy(
  Enum['present', 'absent'] $ensure = $k8s::node::ensure,

  Stdlib::HTTPUrl $master = $k8s::node::master,

  Hash[String, Data] $arguments = {},

  Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR, Array[Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR]]] $cluster_cidr = $k8s::cluster_cidr,

  Enum['cert', 'token', 'incluster'] $auth = $k8s::node::proxy_auth,

  # For cert auth
  Optional[Stdlib::Unixpath] $ca_cert = $k8s::node::ca_cert,
  Optional[Stdlib::Unixpath] $cert = $k8s::node::proxy_cert,
  Optional[Stdlib::Unixpath] $key = $k8s::node::proxy_key,

  # For token and bootstrap auth
  Optional[String[1]] $token = $k8s::node::proxy_token,
) {
  assert_private()

  k8s::binary { 'kube-proxy':
    ensure    => $ensure,
  }

  $kubeconfig = '/srv/kubernetes/kube-proxy.kubeconf'
  case $auth {
    'token': {
      kubeconfig { $kubeconfig:
        ensure          => $ensure,
        owner           => 'kube',
        group           => 'kube',
        server          => $master,
        token           => $token,
        current_context => 'default',
      }
    }
    'cert': {
      kubeconfig { $kubeconfig:
        ensure          => $ensure,
        owner           => 'kube',
        group           => 'kube',
        server          => $master,
        current_context => 'default',

        ca_cert         => $ca_cert,
        client_cert     => $cert,
        client_key      => $key,
      }
    }
    'incluster': {
      if $packaging != 'container' {
        fail('Can only use incluster auth when running as a containerized srevice')
      }
    }
    default: {}
  }

  $_args = k8s::format_arguments({
      cluster_cidr      => $cluster_cidr,
      hostname_override => fact('networking.fqdn'),
      kubeconfig        => $kubeconfig,
      proxy_mode        => 'iptables',
  } + $arguments)

  $_sysconfig_path = pick($k8s::sysconfig_path, '/etc/sysconfig')
  file { "${_sysconfig_path}/kube-proxy":
    content => epp('k8s/sysconfig.epp', {
        comment               => 'Kubernetes kube-proxy configuration',
        environment_variables => {
          'KUBE_PROXY_ARGS' => $_args.join(' '),
        },
    }),
    notify  => Service['kube-proxy'],
  }

  systemd::unit_file { 'kube-proxy.service':
    ensure  => $ensure,
    content => epp('k8s/service.epp', {
      name => 'kube-proxy',

      desc => 'Kubernetes Network Proxy',
      doc  => 'https://github.com/GoogleCloudPlatform/kubernetes',
      bin  => 'kube-proxy',
    }),
    require => [
      File["${_sysconfig_path}/kube-proxy"],
      User['kube'],
    ],
    notify  => Service['kube-proxy'],
  }
  service { 'kube-proxy':
    ensure    => stdlib::ensure($ensure, 'service'),
    enable    => true,
    subscribe => K8s::Binary['kube-proxy'],
  }
}
