# Class: profile::k8s::worker
#
# @param role role in the cluster, server, node, none
# @param master
#   cluster url where the server/nodes connect to.
#   this is most likely a load balanced dns with all the controllers in the backend.
#   on single head clusters this may be the dns name:port of the controller node.
# @param k8s_version version of kubernetes
# @param use_puppetdb whether to use puppetdb or not
# @param manage_firewall whether to manage firewall or not
# @param manage_kube_proxy whether to manage manage_kube_proxy or not, for cilium this is not needed
# @param container_manager set the cri, like cri-o or containerd
#
class profile::k8s::worker (
  Boolean $manage_firewall                   = true,
  Boolean $manage_kube_proxy                 = true,
  Boolean $use_puppetdb                      = true,
  Stdlib::HTTPUrl $master                    = $profile::k8s::controller::master,
  K8s::Container_runtimes $container_manager = 'containerd',
  String[1] $k8s_version                     = $profile::k8s::controller::k8s_version,
  Enum['node'] $role                         = 'node',
) {
  class { 'k8s':
    container_manager  => $container_manager,
    manage_firewall    => $manage_firewall,
    manage_kube_proxy  => $manage_kube_proxy,
    master             => $master,
    puppetdb_discovery => $use_puppetdb,
    role               => $role,
    version            => $k8s_version,
  }
}
