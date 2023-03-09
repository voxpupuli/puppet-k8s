# @summary Installs the kubeadm binary
#
# @param ensure
#
class k8s::install::kubeadm (
  K8s::Ensure $ensure = $k8s::ensure,
) {
  k8s::binary { 'kubeadm':
    ensure => $ensure,
  }
}
