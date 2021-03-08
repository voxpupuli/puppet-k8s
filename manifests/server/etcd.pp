class k8s::server::etcd(
  Boolean $manage_members = false,
  String[1] $cluster_name = 'default',
) {
  include k8s::server::etcd::setup

  if $manage_members {
    # Needs the PuppetDB terminus installed
    $pql_query = @("PQL")
    resources[certname,parameters] {
      type = 'Class' and
      title = 'K8s::Server::Etcd::Setup' and
      nodes {
        resources {
          type = 'Class' and
          title = 'K8s::Server::Etcd' and
          parameters.cluster_name = '${cluster_name}' and
          certname != '${trusted[certname]}'
        }
      }
      order by certname
    }
    | - PQL

    $cluster_nodes = puppetdb_query($pql_query)
    $cluster_nodes.each |$node| {
      k8s::server::etcd::member { $node['certname']:
        peer_urls    => $node['parameters']['initial_advertise_peer_urls'],
        cluster_urls => ['http://localhost:2379'],
      }
    }
  }
}
