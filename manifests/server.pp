class k8s::server(
  Enum['present', 'absent'] $ensure = $k8s::ensure,
  Integer[1] $api_port = 6443,

  Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR] $cluster_cidr = $k8s::cluster_cidr,
  Stdlib::IP::Address::Nosubnet $dns_service_address = $k8s::dns_service_address,
  String $cluster_domain = $k8s::cluster_domain,
  String $direct_master = "https://${fact('networking.ip')}:${api_port}",

  Boolean $manage_etcd = $k8s::manage_etcd,
  Boolean $manage_certs = true,
  Boolean $node_on_server = true,
) {
  include k8s

  if $manage_etcd {
    include k8s::server::etcd
  }
  include k8s::server::tls
  include k8s::server::apiserver
  include k8s::server::controller_manager
  include k8s::server::scheduler
  include k8s::server::resources

  include k8s::node::kubectl
  $_dir = $k8s::server::tls::cert_dir
  kubeconfig { '/root/.kube/config':
    ensure      => $ensure,
    server      => "https://localhost:${api_port}",

    ca_cert     => $k8s::server::tls::ca_cert,
    client_cert => "${_dir}/admin.pem",
    client_key  => "${_dir}/admin.key",

    require     => K8s::Binary['kubectl'],
  }

  if $node_on_server {
    $_dir = $k8s::server::tls::cert_path

    class { 'k8s::node':
      ensure     => $ensure,
      master     => "https://localhost:${api_port}",
      node_auth  => 'cert',
      proxy_auth => 'cert',
      ca_cert    => $k8s::server::tls::ca_cert,
      node_cert  => "${_dir}/node.pem",
      node_key   => "${_dir}/node.key",
      proxy_cert => "${_dir}/kube-proxy.pem",
      proxy_key  => "${_dir}/kube-proxy.key",
    }
  }
}
