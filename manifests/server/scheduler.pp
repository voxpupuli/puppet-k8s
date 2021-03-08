class k8s::server::scheduler(
  Enum['present', 'absent'] $ensure = $k8s::ensure,

  Hash[String,Data] $flags = {},
) {
  k8s::binary { 'kube-scheduler':
    ensure => $ensure,
  }
}
