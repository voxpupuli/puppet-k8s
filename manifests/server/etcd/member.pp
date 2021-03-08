# TODO - Convert to native type

define k8s::server::etcd::member(
  String $peer_urls,
  String $node_name = $title,

  Optional[Array[Stdlib::HTTPUrl]] $cluster_urls = undef,
  Optional[String] $cluster_ca = undef,
) {
  $environment = [
    'ETCDCTL_API=3',
  ] + ($cluster_urls ? {
      undef   => [],
      default => [
        "ETCDCTL_ENDPOINTS=${cluster_urls.join(',')}",
      ],
  }) + ($cluster_ca ? {
      undef   => [],
      default => [
        "ETCDCTL_CACERT=${cluster_ca}",
      ],
  })

  exec { "Add ${node_name} as member":
    environment => $environment,
    command     => "etcdctl member add ${node_name} --peer-urls=\"${peer_urls}\"",
    onlyif      => 'etcdctl endpoint health',
    unless      => "etcdctl -w fields member list | grep \\\"Name\\\" | grep ${node_name} || \
                    etcdctl -w fields member list | grep \\\"PeerURL\\\" | grep ${peer_urls}",
    path        => [ '/bin', '/usr/bin', '/usr/local/bin' ],
    require     => Service['etcd'],
  }
}
