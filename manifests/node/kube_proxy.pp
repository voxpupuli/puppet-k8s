class k8s::node::kube_proxy(
  Enum['present', 'absent'] $ensure => $k8s::ensure,
) {
  k8s::binary { 'kube-proxy':
    ensure => $ensure,
  }

  
}

