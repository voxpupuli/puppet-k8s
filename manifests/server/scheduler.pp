class k8s::server::scheduler(
  Enum['present', 'absent'] $ensure = $k8s::ensure,
) {
  k8s::binary { 'kube-scheduler':
    ensure => $ensure,
  }
}
