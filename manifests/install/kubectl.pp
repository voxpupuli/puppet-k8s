# @summary Installs the kubectl binary
#
# @param ensure
#
class k8s::install::kubectl (
  K8s::Ensure $ensure = $k8s::ensure,
) {
  k8s::binary { 'kubectl':
    ensure => $ensure,
  }
}
