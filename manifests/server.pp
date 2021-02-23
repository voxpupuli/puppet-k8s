class k8s::server(
  Boolean $node_on_server = true,
) {
  include k8s::server::apiserver
  include k8s::server::controller_manager
  include k8s::server::scheduler

  if $node_on_server {
    include k8s::node
  }
}
