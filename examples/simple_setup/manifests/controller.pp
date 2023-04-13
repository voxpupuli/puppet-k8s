# Class: profile::k8s::controller
#
# @param container_manager set the cri, like cri-o or containerd, if controller should be also a worker
# @param etcd_version version of etcd
# @param k8s_version version of kubernetes
# @param manage_firewall whether to manage firewall or not
# @param manage_kube_proxy whether to manage manage_kube_proxy or not
# @param master
#   cluster url where the server/nodes connect to.
#   this is most likely a load balanced dns with all the controllers in the backend.
#   on single head clusters this may be the dns name:port of the controller node.
# @param role role in the cluster, server, node, none
# @param puppetdb_discovery whether to use puppetdb or not
# @param service_cidr address space for the services
# @param pod_cidr address space for the pods
#
# lint:ignore:autoloader_layout
class profile::k8s::controller (
  # lint:endignore
  Boolean $manage_firewall                   = true,                      # k8s-class default: false
  Boolean $manage_kube_proxy                 = true,                      # k8s-class default: true
  Boolean $puppetdb_discovery                = true,                      # k8s-class default: false
  Stdlib::HTTPUrl $master                    = 'https://kubernetes:6443', # k8s-class default: https://kubernetes:6443
  String[1] $etcd_version                    = '3.5.1',                   # k8s-class default: 3.5.1
  String[1] $k8s_version                     = '1.26.1',                  # k8s-class default: 1.26.1
  Enum['server'] $role                       = 'server',                  # k8s-class default: none
  K8s::CIDR $service_cidr                    = '10.20.0.0/20',            # k8s-class default: 10.1.0.0/24
  K8s::CIDR $pod_cidr                        = '10.20.16.0/20',           # k8s-class default: 10.0.0.0/16
  K8s::Container_runtimes $container_manager = $profile::k8s::node::container_manager,
) {
  class { 'k8s':
    container_manager    => $container_manager,
    etcd_version         => $etcd_version,
    manage_firewall      => $manage_firewall,
    manage_kube_proxy    => $manage_kube_proxy,
    master               => $master,
    role                 => $role,
    version              => $k8s_version,
    service_cluster_cidr => $service_cidr,
    cluster_cidr         => $pod_cidr,
    puppetdb_discovery   => $puppetdb_discovery,
  }
}
