class k8s::node(
) {
  include ::k8s::node::kubelet
  include ::k8s::node::kube_proxy
}
