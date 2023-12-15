# @summary Sets up a Kubernetes instance - either as a node or as a server
#
# @param manage_kernel_modules
#   A flag to manage required Kernel modules.
#
# @param manage_sysctl_settings
#   A flag to manage required sysctl settings.
#
# @param manage_kube_proxy
#   How/if the kube-proxy component should be managed, either as an in-cluster
#   component (default), or as an on-node component for advanced use-cases.
# @param ensure
# @param packaging
#
# @param user username for kubernetes files and services
# @param group groupname for kubernetes files and services
# @param uid user id for kubernetes files and services
# @param gid group id for kubernetes files and services
# @param etcd_cluster_name name of the etcd cluster for searching its nodes in the puppetdb
#
class k8s (
  String[1] $version      = '1.26.1',
  String[1] $etcd_version = '3.5.1',

  K8s::Ensure $ensure                     = 'present',
  Enum['container', 'native'] $packaging  = 'native',
  K8s::Native_packaging $native_packaging = 'loose',

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

  String[1] $native_url_template             = 'https://storage.googleapis.com/kubernetes-release/release/v%{version}/bin/%{kernel}/%{arch}/%{binary}',
  String[1] $tarball_url_template            = 'https://dl.k8s.io/v%{version}/kubernetes-%{component}-%{kernel}-%{arch}.tar.gz',
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

  Enum['node','server','etcd-replica','none']  $role = 'none',
  Optional[K8s::Firewall] $firewall_type = undef,

  String[1] $user        = 'kube',
  String[1] $group       = 'kube',
  Integer[0, 65535] $uid = 888,
  Integer[0, 65535] $gid = 888,
) {
  if $role == 'server' {
    include k8s::server
  } elsif $role == 'node' {
    include k8s::node
  } elsif $role == 'etcd-replica' {
    include k8s::server::etcd
  }
}
