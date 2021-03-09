class k8s::server(
  Boolean $manage_certs = true,
  Boolean $node_on_server = true,
) {
  include k8s::server::etcd
  include k8s::server::tls
  include k8s::server::apiserver
  include k8s::server::controller_manager
  include k8s::server::scheduler

  if $node_on_server {
    include k8s::node
  }
}
