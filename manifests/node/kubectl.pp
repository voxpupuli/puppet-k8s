# @summary Installs the kubectl binary
#
# @param ensure Whether to install the binary
class k8s::node::kubectl (
  K8s::Ensure $ensure = $k8s::ensure,
) {
  k8s::binary { 'kubectl':
    ensure => $ensure,
  }
}
