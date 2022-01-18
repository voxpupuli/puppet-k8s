class k8s::node(
  Enum['present', 'absent'] $ensure = $k8s::ensure,

  Stdlib::HTTPUrl $master = $k8s::master,
  Enum['cert', 'token', 'bootstrap'] $node_auth = $k8s::node_auth,
  Enum['cert', 'token', 'incluster'] $proxy_auth = 'incluster',

  Boolean $manage_kubelet = true,
  Boolean $manage_proxy = false,
  Boolean $manage_firewall = $k8s::manage_firewall,
  String[1] $puppetdb_discovery_tag = $k8s::puppetdb_discovery_tag,

  Stdlib::Unixpath $cert_path = '/var/lib/kubelet/pki',
  Optional[Stdlib::Unixpath] $ca_cert = "${cert_path}/ca.pem",

  # For cert auth
  Optional[Stdlib::Unixpath] $node_cert = undef,
  Optional[Stdlib::Unixpath] $node_key = undef,

  Optional[Stdlib::Unixpath] $proxy_cert = undef,
  Optional[Stdlib::Unixpath] $proxy_key = undef,

  # For token and bootstrap auth
  Optional[String[1]] $node_token = undef,
  Optional[String[1]] $proxy_token = undef,
) {
  if $manage_kubelet {
    include k8s::node::kubelet
  }
  if $manage_proxy {
    include k8s::node::kube_proxy
  }
}
