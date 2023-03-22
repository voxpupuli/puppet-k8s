# Class: k8s::node::simple_cni
#
# @summary Provide a simple bridged standard network interface.
#          For basic usage if one does not have flannel, cilium, calico or something else yet.
#          Uses the cni-plugins bridge binary to create a bridge interface to connect the containers
#
# @param pod_cidr cidr for pods in the network
class k8s::node::simple_cni (
  K8s::CIDR $pod_cidr = $k8s::cluster_cidr,
) {
  $bridge = {
    cniVersion => '0.4.0',
    name => 'bridge',
    type => 'bridge',
    bridge => 'cnio0',
    isGateway => true,
    ipMasq => true,
    ipam => {
      type => 'host-local',
      ranges => [[{ subnet => $pod_cidr }]],
      routes => [{ dst => '0.0.0.0/0' }],
    },
  }

  $loopback = {
    cniVersion => '0.4.0',
    name => 'lo',
    type => 'loopback',
  }

  file { '/etc/cni/net.d/10-bridge.conf':
    ensure  => file,
    content => $bridge.to_json,
    require => File['/etc/cni/net.d'],
  }

  file { '/etc/cni/net.d/99-loopback.conf':
    ensure  => file,
    content => $loopback.to_json,
    require => File['/etc/cni/net.d'],
  }
}
