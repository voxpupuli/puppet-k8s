# @summary Installs a Kubernetes node
class k8s::node (
  K8s::Ensure $ensure = $k8s::ensure,

  Stdlib::HTTPUrl $master     = $k8s::master,
  K8s::Node_auth $node_auth   = $k8s::node_auth,
  K8s::Proxy_auth $proxy_auth = 'incluster',

  Boolean $manage_kubelet           = true,
  Boolean $manage_proxy             = false,
  Boolean $manage_firewall          = $k8s::manage_firewall,
  Boolean $manage_kernel_modules    = $k8s::manage_kernel_modules,
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
) {
  if $manage_kubelet {
    include k8s::node::kubelet
  }
  if $manage_proxy {
    include k8s::node::kube_proxy
  }
}
