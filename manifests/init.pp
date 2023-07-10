# @summary Sets up a Kubernetes instance - either as a node or as a server
#
# @param api_service_address IP address for the API service
# @param cluster_cidr CIDR for the pod network
# @param cluster_domain domain name for the cluster
# @param container_image_tag container image tag to use
# @param container_manager container manager to use
# @param container_registry container registry to use
# @param container_runtime_service name of the container runtime service
# @param containerd_package name of the containerd package
# @param control_plane_url URL for the control plane
# @param crictl_package name of the crictl package
# @param crio_package name of the crio package
# @param dns_service_address IP address for the DNS service
# @param ensure whether kubernetes should be present or absent
# @param etcd_cluster_name name of the etcd cluster for searching its nodes in the puppetdb
# @param etcd_version version of etcd to install
# @param firewall_type type of firewall to use
# @param gid group id for kubernetes files and services
# @param group groupname for kubernetes files and services
# @param hyperkube_name name of the hyperkube binary
# @param incluster_control_plane_url URL for the control plane from within the cluster
# @param manage_container_manager whether to manage the container manager
# @param manage_etcd whether to manage etcd
# @param manage_firewall whether to manage the firewall
# @param manage_image whether to manage the image
# @param manage_kernel_modules A flag to manage required Kernel modules.
# @param manage_kube_proxy How/if the kube-proxy component should be managed, either as an in-cluster component (default), or as an on-node component for advanced use-cases.
# @param manage_packages whether to manage packages
# @param manage_repo whether to manage the repo
# @param manage_sysctl_settings A flag to manage required sysctl settings.
# @param native_packaging type of native packaging to use
# @param native_url_template template for native packaging
# @param node_auth authentication method for nodes
# @param package_template template for package names
# @param packaging whether to use native or container packaging
# @param puppetdb_discovery whether to use puppetdb for node discovery
# @param puppetdb_discovery_tag tag to use for puppetdb node discovery
# @param purge_manifests whether to purge manifests
# @param role role of the node
# @param runc_version version of runc to install
# @param service_cluster_cidr CIDR for the service network
# @param sysconfig_path path to the sysconfig directory
# @param tarball_url_template template for tarball packaging
# @param uid user id for kubernetes files and services
# @param user username for kubernetes files and services
# @param version version of kubernetes to install
#
class k8s (
  K8s::Ensure $ensure                     = 'present',
  Enum['container', 'native'] $packaging  = 'native',
  K8s::Native_packaging $native_packaging = 'loose',
  String[1] $version                      = '1.28.14',
  String[1] $etcd_version                 = '3.5.16',

  String[1] $container_registry              = 'registry.k8s.io',
  Optional[String[1]] $container_image_tag   = undef,

  K8s::Container_runtimes $container_manager = 'crio',
  String[1] $container_runtime_service       = "${container_manager}.service",
  Optional[String[1]] $crio_package          = undef,
  Optional[String[1]] $containerd_package    = undef,
  Optional[String[1]] $crictl_package        = undef,
  String[1] $runc_version                    = 'installed',

  Boolean $manage_etcd                 = true,
  Boolean $manage_firewall             = false,
  Boolean $manage_kernel_modules       = true,
  Boolean $manage_sysctl_settings      = true,
  Boolean $manage_image                = false,
  Boolean $manage_repo                 = true,
  Boolean $manage_packages             = true,
  Boolean $manage_container_manager    = true,
  K8s::Proxy_method $manage_kube_proxy = true,

  Boolean $puppetdb_discovery       = false,
  String[1] $puppetdb_discovery_tag = 'default',

  Boolean $purge_manifests = true,

  String[1] $native_url_template             = 'https://dl.k8s.io/release/v%{version}/bin/%{kernel}/%{arch}/%{binary}',
  String[1] $tarball_url_template            = 'https://dl.k8s.io/release/v%{version}/kubernetes-%{component}-%{kernel}-%{arch}.tar.gz',
  String[1] $package_template                = 'kubernetes-%{component}',
  String[1] $hyperkube_name                  = 'hyperkube',
  Optional[Stdlib::Unixpath] $sysconfig_path = undef,

  K8s::Node_auth $node_auth = 'bootstrap',

  Stdlib::HTTPUrl $incluster_control_plane_url       = 'https://kubernetes.default.svc',
  Stdlib::HTTPUrl $control_plane_url                 = 'https://kubernetes:6443',
  K8s::CIDR $service_cluster_cidr                    = '10.1.0.0/24',
  K8s::CIDR $cluster_cidr                            = '10.0.0.0/16',
  Stdlib::IP::Address::Nosubnet $api_service_address = k8s::ip_in_cidr($service_cluster_cidr, 'first'),
  K8s::IP_addresses $dns_service_address             = k8s::ip_in_cidr($service_cluster_cidr, 'second'),
  Stdlib::Fqdn $cluster_domain                       = 'cluster.local',
  String[1] $etcd_cluster_name                       = 'default',

  Enum['node','server','none']  $role    = 'none',
  Optional[K8s::Firewall] $firewall_type = undef,

  String[1] $user        = 'kube',
  String[1] $group       = 'kube',
  Integer[0, 65535] $uid = 888,
  Integer[0, 65535] $gid = 888,
) {
  if $manage_container_manager {
    include k8s::install::container_runtime
  }

  group { $group:
    ensure => present,
    system => true,
    gid    => $gid,
  }

  user { $user:
    ensure     => present,
    comment    => 'Kubernetes user',
    gid        => $group,
    home       => '/srv/kubernetes',
    managehome => false,
    shell      => (fact('os.family') ? {
        'Debian' => '/usr/sbin/nologin',
        default  => '/sbin/nologin',
    }),
    system     => true,
    uid        => $uid,
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
    owner  => $user,
    group  => $group,
  }

  $_sysconfig_path = pick($sysconfig_path, '/etc/sysconfig')
  file { "${_sysconfig_path}/kube-common":
    ensure  => file,
    content => epp('k8s/sysconfig.epp', {
        comment               => 'General Kubernetes Configuration',
        environment_variables => {
          'KUBE_LOG_LEVEL'   => '',
        },
    }),
  }

  file {
    default:
      ensure => directory;

    '/etc/kubernetes': ;
    '/etc/kubernetes/certs': ;
    '/etc/kubernetes/manifests':
      purge   => $purge_manifests,
      recurse => true;
    '/root/.kube': ;
    '/srv/kubernetes':
      owner => $user,
      group => $group;
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

    ensure_packages([$_conntrack,])
  }

  if $role != 'none' {
    include k8s::install::cni_plugins
  }

  if $role == 'server' {
    include k8s::server
  } elsif $role == 'node' {
    include k8s::node
  }
}
