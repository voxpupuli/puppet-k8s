# @summary Sets up a on-node kube-proxy instance
#
# For most use-cases, running kube-proxy inside the cluster itself is recommended
class k8s::node::kube_proxy (
  K8s::Ensure $ensure = $k8s::node::ensure,

  Stdlib::HTTPUrl $master = $k8s::node::master,

  Hash[String, Data] $config     = {},
  Hash[String, Data] $arguments  = {},
  String $puppetdb_discovery_tag = $k8s::node::puppetdb_discovery_tag,

  K8s::Cidr $cluster_cidr = $k8s::cluster_cidr,

  K8s::Proxy_auth $auth = $k8s::node::proxy_auth,

  # For cert auth
  Optional[Stdlib::Unixpath] $ca_cert = $k8s::node::ca_cert,
  Optional[Stdlib::Unixpath] $cert    = $k8s::node::proxy_cert,
  Optional[Stdlib::Unixpath] $key     = $k8s::node::proxy_key,

  # For token and bootstrap auth
  Optional[String[1]] $token = $k8s::node::proxy_token,
) {
  assert_private()

  if $auth == 'incluster' and $k8s::packaging != 'container' {
    # If the proxy is set to incluster auth then it will expect to run as a cluster service
    $_ensure = absent
  } else {
    $_ensure = $ensure
  }

  k8s::binary { 'kube-proxy':
    ensure => $_ensure,
  }

  $kubeconfig = '/srv/kubernetes/kube-proxy.kubeconf'
  case $auth {
    'token': {
      kubeconfig { $kubeconfig:
        ensure          => $_ensure,
        owner           => 'kube',
        group           => 'kube',
        server          => $master,
        token           => $token,
        current_context => 'default',
        ca_cert         => $ca_cert,
        notify          => Service['kube-proxy'],
      }
    }
    'cert': {
      kubeconfig { $kubeconfig:
        ensure          => $_ensure,
        owner           => 'kube',
        group           => 'kube',
        server          => $master,
        client_cert     => $cert,
        client_key      => $key,
        current_context => 'default',
        ca_cert         => $ca_cert,
        notify          => Service['kube-proxy'],
      }
    }
    default: {}
  }

  $config_hash = {
    'apiVersion'       => 'kubeproxy.config.k8s.io/v1alpha1',
    'kind'             => 'KubeProxyConfiguration',

    'clusterCIDR'      => $cluster_cidr,
  } + $config

  file { '/etc/kubernetes/kube-proxy.conf':
    ensure  => $_ensure,
    content => to_yaml($config_hash),
    owner   => 'kube',
    group   => 'kube',
    notify  => Service['kube-proxy'],
  }

  $_args = k8s::format_arguments({
      config     => '/etc/kubernetes/kube-proxy.conf',
      kubeconfig => $kubeconfig,
  } + $arguments)

  if $k8s::packaging == 'container' {
  } else {
    $_sysconfig_path = pick($k8s::sysconfig_path, '/etc/sysconfig')
    file { "${_sysconfig_path}/kube-proxy":
      ensure  => $_ensure,
      content => epp('k8s/sysconfig.epp', {
          comment               => 'Kubernetes kube-proxy configuration',
          environment_variables => {
            'KUBE_PROXY_ARGS' => $_args.join(' '),
          },
      }),
      notify  => Service['kube-proxy'],
    }

    systemd::unit_file { 'kube-proxy.service':
      ensure  => $_ensure,
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
      ensure    => stdlib::ensure($_ensure, 'service'),
      enable    => $_ensure == 'present',
      subscribe => K8s::Binary['kube-proxy'],
    }
  }
}
