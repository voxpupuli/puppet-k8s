class k8s::server::apiserver(
  Enum['present', 'absent'] $ensure = $k8s::ensure,

  Hash[String,Data] $flags = {},
) {
  k8s::binary { 'kube-apiserver':
    ensure => $ensure,
  }
}
