# TODO - Convert to native type

define k8s::server::etcd::member(
  Array[String, 1] $peer_urls,

  Optional[Array[Stdlib::HTTPUrl]] $cluster_urls = undef,
  Optional[Stdlib::Unixpath] $cluster_ca = undef,
  Optional[Stdlib::Unixpath] $cluster_cert = undef,
  Optional[Stdlib::Unixpath] $cluster_key = undef,
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
  }) + ($cluster_cert ? {
      undef   => [],
      default => [
        "ETCDCTL_CERT=${cluster_cert}",
      ],
  }) + ($cluster_key ? {
      undef   => [],
      default => [
        "ETCDCTL_CERT=${cluster_key}",
      ],
  })

  Service <| title == 'etcd' |>
  -> exec { "Add ${name} as member":
    environment => $environment,
    command     => "etcdctl member add ${name} --peer-urls=\"${peer_urls.join(',')}\"",
    onlyif      => 'etcdctl endpoint health',
    unless      => "etcdctl -w fields member list | grep \\\"Name\\\" | grep ${name} || \
                    etcdctl -w fields member list | grep \\\"PeerURL\\\" | grep ${peer_urls}",
    path        => [ '/bin', '/usr/bin', '/usr/local/bin' ],
  }
}
