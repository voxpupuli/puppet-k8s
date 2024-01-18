# @summary Installs and configures kubelet
#
# @param arguments additional arguments to pass to kubelet
# @param auth type of node authentication
# @param ca_cert path to the ca cert
# @param cert path to node cert file
# @param cert_path path to cert files
# @param config additional config to pass to kubelet
# @param control_plane_url cluster API connection
# @param ensure set ensure for installation or deinstallation
# @param firewall_type define the type of firewall to use
# @param key path to node key file
# @param kubeconfig path to kubeconfig
# @param manage_firewall whether to manage firewall or not
# @param manage_kernel_modules whether to load kernel modules or not
# @param manage_sysctl_settings whether to manage sysctl settings or not
# @param puppetdb_discovery_tag enable puppetdb resource searching
# @param rotate_server_tls whether to rotate server tls or not
# @param runtime which container runtime to use
# @param runtime_service name of the service of the container runtime
# @param support_dualstack whether to support dualstack or not
# @param token k8s token to join a cluster
#
class k8s::node::kubelet (
  K8s::Ensure $ensure = $k8s::node::ensure,

  Stdlib::HTTPUrl $control_plane_url = $k8s::node::control_plane_url,

  Hash[String, Data] $config        = {},
  Hash[String, Data] $arguments     = {},
  String $runtime                   = $k8s::container_manager,
  String $runtime_service           = $k8s::container_runtime_service,
  String[1] $puppetdb_discovery_tag = $k8s::node::puppetdb_discovery_tag,

  K8s::Node_auth $auth            = $k8s::node::node_auth,
  Boolean $rotate_server_tls      = $auth == 'bootstrap',
  Boolean $manage_firewall        = $k8s::node::manage_firewall,
  Boolean $manage_kernel_modules  = $k8s::node::manage_kernel_modules,
  Boolean $manage_sysctl_settings = $k8s::node::manage_sysctl_settings,
  Boolean $support_dualstack      = $k8s::cluster_cidr =~ Array[Data, 2],

  Stdlib::Unixpath $cert_path  = $k8s::node::cert_path,
  Stdlib::Unixpath $kubeconfig = '/srv/kubernetes/kubelet.kubeconf',

  # For cert auth
  Optional[Stdlib::Unixpath] $ca_cert = $k8s::node::ca_cert,
  Optional[Stdlib::Unixpath] $cert    = $k8s::node::node_cert,
  Optional[Stdlib::Unixpath] $key     = $k8s::node::node_key,

  # For token and bootstrap auth
  Optional[Sensitive[String]] $token  = $k8s::node::node_token,

  Optional[K8s::Firewall] $firewall_type = $k8s::node::firewall_type,
) {
  k8s::binary { 'kubelet':
    ensure => $ensure,
    notify => Service['kubelet'],
  }

  if $auth == 'bootstrap' {
    $_bootstrap_kubeconfig = '/srv/kubernetes/bootstrap-kubelet.kubeconf'
  } else {
    $_bootstrap_kubeconfig = undef
  }

  case $auth {
    'bootstrap': {
      $_ca_cert = pick($ca_cert, '/var/lib/kubelet/pki/ca.pem')
      ensure_packages(['jq'])
      if !defined(K8s::Binary['kubectl']) {
        k8s::binary { 'kubectl':
          ensure => $ensure,
        }
      }
      exec { 'Remove broken CA':
        path    => ['/usr/local/bin','/usr/bin','/bin'],
        command => "rm '${_ca_cert}'",
        onlyif  => "stat '${_ca_cert}' | grep 'Size: 0'",
      }
      ~> exec { 'Retrieve K8s CA':
        path    => ['/usr/local/bin','/usr/bin','/bin'],
        command => "kubectl --server='${control_plane_url}' --username=anonymous --insecure-skip-tls-verify=true \
          get --raw /api/v1/namespaces/kube-system/configmaps/cluster-info | jq .data.ca -r > '${_ca_cert}'",
        creates => $_ca_cert,
        require => [
          K8s::Binary['kubectl'],
          Package['jq'],
        ],
      }
      -> kubeconfig { $_bootstrap_kubeconfig:
        ensure          => $ensure,
        owner           => $k8s::user,
        group           => $k8s::group,
        server          => $control_plane_url,
        current_context => 'default',
        token           => $token.unwrap,

        ca_cert         => $_ca_cert,

        notify          => Service['kubelet'],
      }
      File <| title == $_ca_cert |> -> Kubeconfig[$_bootstrap_kubeconfig]
      $_authentication_hash = {
        'authentication'     => {
          'x509' => {
            'clientCAFile' => $_ca_cert,
          },
        },
      }
    }
    'token': {
      kubeconfig { $kubeconfig:
        ensure          => $ensure,
        owner           => $k8s::user,
        group           => $k8s::group,
        server          => $control_plane_url,
        current_context => 'default',
        token           => $token.unwrap,
        notify          => Service['kubelet'],
      }
      $_authentication_hash = {}
    }
    'cert': {
      kubeconfig { $kubeconfig:
        ensure          => $ensure,
        owner           => $k8s::user,
        group           => $k8s::group,
        server          => $control_plane_url,
        current_context => 'default',

        ca_cert         => $ca_cert,
        client_cert     => $cert,
        client_key      => $key,
        notify          => Service['kubelet'],
      }
      $_authentication_hash = {
        'authentication'     => {
          'x509' => {
            'clientCAFile' => $ca_cert,
          },
        },
      }
    }
    default: {
    }
  }

  if fact('systemd_internal_services."systemd-resolved.service"') == 'enabled' {
    $systemd_resolved_fix = { 'resolvConf' => '/run/systemd/resolve/resolv.conf' }
  } else {
    $systemd_resolved_fix = {}
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
    'clusterDNS'         => [
      $k8s::dns_service_address,
    ].flatten,
    'cgroupDriver'       => 'systemd',
  } + $_authentication_hash + $systemd_resolved_fix

  if $manage_kernel_modules {
    kmod::load {
      default:
        ensure => $ensure;

      'overlay':;
      'br_netfilter':;
    }
  }

  if $manage_sysctl_settings {
    sysctl {
      default:
        ensure => $ensure,
        silent => true,
        value  => '1';

      'net.bridge.bridge-nf-call-iptables':
        before => Sysctl['net.ipv4.ip_forward'];
      'net.bridge.bridge-nf-call-ip6tables':
        before => Sysctl['net.ipv6.conf.all.forwarding'];
      'net.ipv4.ip_forward':;
      'net.ipv6.conf.all.forwarding':;
    }

    if $manage_kernel_modules {
      Kmod::Load['br_netfilter']
      -> [
        Sysctl['net.bridge.bridge-nf-call-iptables'],
        Sysctl['net.bridge.bridge-nf-call-ip6tables']
      ]
    }
  }

  file { '/etc/kubernetes/kubelet.conf':
    ensure  => $ensure,
    content => to_yaml($config_hash + $config),
    owner   => $k8s::user,
    group   => $k8s::group,
    notify  => Service['kubelet'],
  }

  if $runtime in ['crio', 'containerd'] {
    $_runtime_endpoint = "unix:///var/run/${runtime}/${runtime}.sock"
  } else {
    $_runtime_endpoint = undef
  }

  if $support_dualstack and fact('networking.ip') and fact('networking.ip6') {
    $_node_ip = [fact('networking.ip'), fact('networking.ip6')]
  } else {
    $_node_ip = undef
  }

  $_args = k8s::format_arguments({
      config                     => '/etc/kubernetes/kubelet.conf',
      kubeconfig                 => $kubeconfig,
      bootstrap_kubeconfig       => $_bootstrap_kubeconfig,
      cert_dir                   => $cert_path,
      container_runtime_endpoint => $_runtime_endpoint,
      hostname_override          => fact('networking.fqdn'),
      node_ip                    => $_node_ip,
  } + $arguments)

  $_sysconfig_path = pick($k8s::sysconfig_path, '/etc/sysconfig')
  file { "${_sysconfig_path}/kubelet":
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
        needs => [$runtime_service,],
        bin   => 'kubelet',
    }),
    require => [
      File["${_sysconfig_path}/kubelet", '/etc/kubernetes/kubelet.conf'],
      User[$k8s::user],
    ],
    notify  => Service['kubelet'],
  }
  service { 'kubelet':
    ensure => stdlib::ensure($ensure, 'service'),
    enable => true,
  }

  Class['k8s::install::container_runtime'] -> Service['kubelet']
  Package <| title == 'containernetworking-plugins' |> -> Service['kubelet']

  if $manage_firewall {
    if $facts['firewalld_version'] {
      $_firewall_type = pick($firewall_type, 'firewalld')
    } else {
      $_firewall_type = pick($firewall_type, 'iptables')
    }

    case $_firewall_type {
      'firewalld' : {
        firewalld_custom_service { 'kubelet':
          ensure      => $ensure,
          short       => 'kubelet',
          description => 'Kubernetes kubelet daemon',
          ports       => [
            {
              port     => '10250',
              protocol => 'tcp',
            },
          ],
        }
        firewalld_service { 'Allow k8s kubelet access':
          ensure  => $ensure,
          zone    => 'public',
          service => 'kubelet',
        }
      }
      'iptables': {
        include firewall

        firewall { '100 allow kubelet access':
          dport => 10250,
          proto => 'tcp',
          jump  => 'accept',
        }
      }
      default: {}
    }
  }
}
