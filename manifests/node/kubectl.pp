class k8s::node::kubectl(
  Enum['present', 'absent'] $ensure = $k8s::ensure,
) {
  k8s::binary { 'kubectl':
    ensure    => $ensure,
  }
}
