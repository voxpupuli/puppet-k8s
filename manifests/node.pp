# @summary Installs a Kubernetes node
#
# @param ca_cert path to the ca cert
# @param cert_path path to cert files
# @param control_plane_url cluster API connection
# @param ensure set ensure for installation or deinstallation
# @param firewall_type define the type of firewall to use
# @param manage_crictl toggle to install crictl
# @param manage_firewall whether to manage firewall or not
# @param manage_kernel_modules whether to load kernel modules or not
# @param manage_kubelet whether to manage kublet or not
# @param manage_proxy whether to manage kube-proxy or not
# @param manage_simple_cni toggle to use a simple bridge network for containers
# @param manage_sysctl_settings whether to manage sysctl settings or not
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

  Stdlib::HTTPUrl $control_plane_url = $k8s::control_plane_url,
  K8s::Node_auth $node_auth          = $k8s::node_auth,
  K8s::Proxy_auth $proxy_auth        = 'incluster',

  Boolean $manage_kubelet           = true,
  Boolean $manage_proxy             = $k8s::manage_kube_proxy == 'on-node',
  Boolean $manage_crictl            = false,
  Boolean $manage_firewall          = $k8s::manage_firewall,
  Boolean $manage_kernel_modules    = $k8s::manage_kernel_modules,
  Boolean $manage_sysctl_settings   = $k8s::manage_sysctl_settings,
  Boolean $manage_simple_cni        = false,
  String[1] $puppetdb_discovery_tag = $k8s::puppetdb_discovery_tag,

  Stdlib::Unixpath $cert_path = '/var/lib/kubelet/pki',
  Stdlib::Unixpath $ca_cert   = "${cert_path}/ca.pem",

  # For cert auth
  Optional[Stdlib::Unixpath] $node_cert = undef,
  Optional[Stdlib::Unixpath] $node_key  = undef,

  Optional[Stdlib::Unixpath] $proxy_cert = undef,
  Optional[Stdlib::Unixpath] $proxy_key  = undef,

  # For token and bootstrap auth
  Optional[Sensitive[String]] $node_token  = undef,
  Optional[Sensitive[String]] $proxy_token = undef,

  Optional[K8s::Firewall] $firewall_type = $k8s::firewall_type,
) {
  include k8s::common
  include k8s::install::cni_plugins

  if $k8s::manage_container_manager {
    include k8s::install::container_runtime
  }
  if $k8s::manage_repo {
    include k8s::repo
  }
  if $k8s::manage_packages {
    # Ensure conntrack is installed to properly handle networking cleanup
    $_conntrack = fact('os.family') ? {
      'Debian' => 'conntrack',
      default  => 'conntrack-tools',
    }
    ensure_packages([$_conntrack,])
  }

  if $manage_crictl {
    include k8s::install::crictl
  }
  if $manage_kubelet {
    include k8s::node::kubelet
  }
  if $manage_proxy {
    include k8s::node::kube_proxy
  }
  if $manage_simple_cni {
    include k8s::node::simple_cni
  }
}
