# @summary Sets up a Kubernetes instance - either as a node or as a server
class k8s (
  K8s::Ensure $ensure       = 'present',
  Enum['container', 'native'] $packaging  = 'native',
  K8s::Native_packaging $native_packaging = 'loose',
  String[1] $version                      = '1.20.14',
  String[1] $etcd_version                 = '3.5.1',

  String[1] $container_registry             = 'gcr.io/google_containers',
  String[1] $container_image                = 'hyperkube',
  Optional[String] $container_image_tag     = undef,
  Enum['docker', 'crio'] $container_manager = 'crio',
  String[1] $container_runtime_service      = "${container_manager}.service",
  Optional[String[1]] $crio_package         = undef,
  String[1] $runc_version                   = 'installed',

  Boolean $manage_etcd              = true,
  Boolean $manage_firewall          = false,
  Boolean $manage_image             = false,
  Boolean $manage_repo              = true,
  Boolean $manage_packages          = true,
  Boolean $manage_container_manager = true,
  Boolean $manage_kube_proxy        = true,
  Boolean $puppetdb_discovery       = false,
  String[1] $puppetdb_discovery_tag = 'default',

  Boolean $purge_manifests = true,

  String[1] $native_url_template             = 'https://storage.googleapis.com/kubernetes-release/release/v%{version}/bin/%{kernel}/%{arch}/%{binary}',
  String[1] $tarball_url_template            = 'https://dl.k8s.io/v%{version}/kubernetes-%{component}-%{kernel}-%{arch}.tar.gz',
  String[1] $package_template                = 'kubernetes-%{component}',
  String[1] $hyperkube_name                  = 'hyperkube',
  Optional[Stdlib::Unixpath] $sysconfig_path = undef,

  K8s::Node_auth $node_auth = 'bootstrap',

  Stdlib::HTTPUrl $incluster_master                  = 'https://kubernetes.default.svc',
  Stdlib::HTTPUrl $master                            = 'https://kubernetes:6443',
  Optional[Array[Stdlib::HTTPUrl]] $etcd_servers     = undef,
  K8s::CIDR $service_cluster_cidr                    = '10.1.0.0/24',
  K8s::CIDR $cluster_cidr                            = '10.0.0.0/16',
  Stdlib::IP::Address::Nosubnet $api_service_address = k8s::ip_in_cidr($service_cluster_cidr, 'first'),
  K8s::IP_addresses $dns_service_address             = k8s::ip_in_cidr($service_cluster_cidr, 'second'),
  Stdlib::Fqdn $cluster_domain                       = 'cluster.local',

  Enum['node','server','none']  $role = 'none',
) {
  if $manage_container_manager {
    if $container_manager == 'docker' {
      $pkg = 'docker'
    } else {
      if fact('os.family') == 'Debian' {
        $_crio_version = $version.split('\.')[0, 2].join('.')
        if versioncmp($_crio_version, '1.17') < 0 {
          $pkg = pick($crio_package, "cri-o-${_crio_version}")
        } else {
          $pkg = pick($crio_package, 'cri-o')
        }

        # Avoid a potential issue with some CRI-o versions
        file { ['/usr/lib/cri-o-runc/sbin', '/usr/lib/cri-o-runc']:
          ensure => directory,
        }
        file { '/usr/lib/cri-o-runc/sbin/runc':
          ensure  => link,
          target  => '/usr/sbin/runc',
          replace => false,
        }
      } else {
        $pkg = pick($crio_package, 'cri-o')
      }

      file { '/usr/libexec/crio/conmon':
        ensure  => link,
        target  => '/usr/bin/conmon',
        replace => false,
        require => Package['k8s container manager'],
      }
      file { '/etc/cni/net.d/100-crio-bridge.conf':
        ensure  => absent,
        require => Package['k8s container manager'],
      }
    }

    package { 'k8s container manager':
      name => $pkg,
    }
    -> file_line { 'K8s crio cgroup manager':
      path  => '/etc/crio/crio.conf',
      line  => 'cgroup_manager = "systemd"',
      match => '^cgroup_manager',
    }

    # is needed by cri-o but its not a dependency of the package
    package { 'runc':
      ensure => $runc_version,
    }

    if $manage_repo {
      Class['k8s::repo'] -> Package['k8s container manager']
    }
  }

  group { 'kube':
    ensure => present,
    system => true,
    gid    => 888,
  }
  user { 'kube':
    ensure     => present,
    comment    => 'Kubernetes user',
    gid        => 'kube',
    home       => '/srv/kubernetes',
    managehome => false,
    shell      => (fact('os.family') ? {
        'Debian' => '/usr/sbin/nologin',
        default  => '/sbin/nologin',
    }),
    system     => true,
    uid        => 888,
  }

  file {
    default:
      ensure  => directory,
      force   => true,
      purge   => true,
      recurse => true;

    '/opt/k8s': ;
    '/opt/k8s/bin': ;
  }
  file { '/var/run/kubernetes':
    ensure => directory,
    owner  => 'kube',
    group  => 'kube',
  }

  $_sysconfig_path = pick($sysconfig_path, '/etc/sysconfig')
  file { "${_sysconfig_path}/kube-common":
    ensure  => file,
    content => epp('k8s/sysconfig.epp', {
        comment               => 'General Kubernetes Configuration',
        environment_variables => {
          # 'KUBE_LOGTOSTDERR' => '--alsologtostderr',
          'KUBE_LOG_LEVEL'   => '',
        },
    }),
  }

  file {
    default:
      ensure => directory;

    '/etc/cni': ;
    '/etc/cni/net.d': ;
    '/opt/cni': ;
    '/opt/cni/bin': ;

    '/etc/kubernetes': ;
    '/etc/kubernetes/certs': ;
    '/etc/kubernetes/manifests':
      purge   => $purge_manifests,
      recurse => true;
    '/root/.kube': ;
    '/srv/kubernetes':
      owner => 'kube',
      group => 'kube';
    '/usr/libexec/kubernetes': ;
    '/var/lib/kubelet': ;
    '/var/lib/kubelet/pki': ;

    '/usr/share/containers/': ;
    '/usr/share/containers/oci/': ;
    '/usr/share/containers/oci/hooks.d': ;
  }

  if $manage_repo {
    include k8s::repo
  }
  if $manage_packages {
    # Ensure conntrack is installed to properly handle networking cleanup
    if fact('os.family') == 'Debian' {
      $_conntrack = 'conntrack'
    } else {
      $_conntrack = 'conntrack-tools'
    }

    ensure_packages([
        'containernetworking-plugins',
        $_conntrack,
    ])
    if $manage_repo {
      Class['k8s::repo'] -> Package['containernetworking-plugins']
    }
  }

  if $role == 'server' {
    include k8s::server
  } elsif $role == 'node' {
    include k8s::node
  }
}
