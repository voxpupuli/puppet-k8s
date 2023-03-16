# @summary Installs a Kubernetes node
#
# @param ca_cert path to the ca cert
# @param cert_path path to cert files
# @param ensure set ensure for installation or deinstallation
# @param firewall_type define the type of firewall to use
# @param manage_firewall whether to manage firewall or not
# @param manage_kernel_modules whether to load kernel modules or not
# @param manage_kubelet whether to manage kublet or not
# @param manage_proxy whether to manage kube-proxy or not
# @param manage_sysctl_settings whether to manage sysctl settings or not
# @param master cluster API connection
# @param node_auth type of node authentication
# @param node_cert path to node cert file
# @param node_key path to node key file
# @param node_token k8s token to join a cluster
# @param proxy_auth which proxy auth to use
# @param proxy_cert path to proxy cert file
# @param proxy_key path to proxy key file
# @param proxy_token k8s token for kube-proxy
# @param puppetdb_discovery_tag enable puppetdb resource searching
#
class k8s::node (
  K8s::Ensure $ensure = $k8s::ensure,

  Stdlib::HTTPUrl $master     = $k8s::master,
  K8s::Node_auth $node_auth   = $k8s::node_auth,
  K8s::Proxy_auth $proxy_auth = 'incluster',

  Boolean $manage_kubelet           = true,
  Boolean $manage_proxy             = false,
  Boolean $manage_firewall          = $k8s::manage_firewall,
  Boolean $manage_kernel_modules    = $k8s::manage_kernel_modules,
  Boolean $manage_sysctl_settings   = $k8s::manage_sysctl_settings,
  String[1] $puppetdb_discovery_tag = $k8s::puppetdb_discovery_tag,

  Stdlib::Unixpath $cert_path = '/var/lib/kubelet/pki',
  Stdlib::Unixpath $ca_cert   = "${cert_path}/ca.pem",

  # For cert auth
  Optional[Stdlib::Unixpath] $node_cert = undef,
  Optional[Stdlib::Unixpath] $node_key  = undef,

  Optional[Stdlib::Unixpath] $proxy_cert = undef,
  Optional[Stdlib::Unixpath] $proxy_key  = undef,

  # For token and bootstrap auth
  Optional[String[1]] $node_token  = undef,
  Optional[String[1]] $proxy_token = undef,

  Optional[K8s::Firewall] $firewall_type = $k8s::firewall_type,
) {
  if $manage_kubelet {
    include k8s::node::kubelet
  }
  if $manage_proxy {
    include k8s::node::kube_proxy
  }
}
