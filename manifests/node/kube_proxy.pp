# @summary Sets up a on-node kube-proxy instance
# @api private
#
# For most use-cases, running kube-proxy inside the cluster itself is recommended
#
# @param arguments A hash of additional arguments to pass to kube-proxy
# @param auth The authentication method to use for the API server
# @param ca_cert The path to the CA certificate to use for the API server
# @param cert The path to the client certificate to use for the API server
# @param cluster_cidr The CIDR range of the cluster
# @param config A hash of additional configuration options to pass to kube-proxy
# @param control_plane_url The URL of the Kubernetes API server
# @param ensure Whether the kube-proxy service should be configured
# @param key The path to the client key to use for the API server
# @param puppetdb_discovery_tag The tag to use for PuppetDB service discovery
# @param token The token to use for the API server
#
class k8s::node::kube_proxy (
  K8s::Ensure $ensure = $k8s::node::ensure,

  Stdlib::HTTPUrl $control_plane_url = $k8s::node::control_plane_url,

  Hash[String, Data] $config     = {},
  Hash[String, Data] $arguments  = {},
  String $puppetdb_discovery_tag = $k8s::node::puppetdb_discovery_tag,

  K8s::CIDR $cluster_cidr = $k8s::cluster_cidr,

  K8s::Proxy_auth $auth = $k8s::node::proxy_auth,

  # For cert auth
  Optional[Stdlib::Unixpath] $ca_cert = $k8s::node::ca_cert,
  Optional[Stdlib::Unixpath] $cert    = $k8s::node::proxy_cert,
  Optional[Stdlib::Unixpath] $key     = $k8s::node::proxy_key,

  # For token and bootstrap auth
  Optional[Sensitive[String]] $token = $k8s::node::proxy_token,
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
        owner           => $k8s::user,
        group           => $k8s::group,
        server          => $control_plane_url,
        token           => $token.unwrap,
        current_context => 'default',
        ca_cert         => $ca_cert,
        notify          => Service['kube-proxy'],
      }
    }
    'cert': {
      kubeconfig { $kubeconfig:
        ensure          => $_ensure,
        owner           => $k8s::user,
        group           => $k8s::group,
        server          => $control_plane_url,
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
    owner   => $k8s::user,
    group   => $k8s::group,
    notify  => Service['kube-proxy'],
  }

  $_args = k8s::format_arguments({
      config     => '/etc/kubernetes/kube-proxy.conf',
      kubeconfig => $kubeconfig,
  } + $arguments)

  if $k8s::packaging == 'container' {
  } else {
    file { "${k8s::sysconfig_path}/kube-proxy":
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
        File["${k8s::sysconfig_path}/kube-proxy"],
        User[$k8s::user],
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
