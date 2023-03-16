# @summary Installs the kubeadm binary
#
# @param ensure set ensure for installation or deinstallation
#
class k8s::install::kubeadm (
  K8s::Ensure $ensure = $k8s::ensure,
) {
  k8s::binary { 'kubeadm':
    ensure => $ensure,
  }
}
