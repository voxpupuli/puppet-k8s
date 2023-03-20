# Class: k8s::node::simple_cni
#
#
class k8s::node::simple_cni (
  K8s::CIDR $pod_cidr = '10.0.0.0/24'
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
