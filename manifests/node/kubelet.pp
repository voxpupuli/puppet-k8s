class k8s::node::kubelet(
  Enum['present', 'absent'] $ensure => $k8s::ensure,
) {
  k8s::binary { 'kubelet':
    ensure => $ensure,
  }

  
}

