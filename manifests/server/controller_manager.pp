class k8s::server::controller_manager(
  Enum['present', 'absent'] $ensure = $k8s::ensure,
) {
  k8s::binary { 'kube-controller-manager':
    ensure => $ensure,
  }

  
}
