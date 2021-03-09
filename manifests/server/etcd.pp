class k8s::server::etcd(
  Boolean $manage_members = false,
  String[1] $cluster_name = 'default',

  Boolean $generate_ca = false,
  Stdlib::Unixpath $cert_path = '/var/lib/etcd/certs',
  Stdlib::Unixpath $ca_key = "${cert_path}/ca.key",
  Stdlib::Unixpath $ca_cert = "${cert_path}/ca.pem",
) {
  if $generate_ca {
    k8s::server::tls::ca { 'etcd-ca':
      key  => $ca_key,
      cert => $ca_cert,
    }
  }

  k8s::server::tls::cert {
    default:
      cert_path => $cert_path,
      ca_key    => $ca_key,
      ca_cert   => $ca_cert;

    'etcd-peer':
      addn_names         => [
        fact('networking.fqdn'),
        fact('networking.ip'),
        fact('networking.ip6'),
      ],
      distinguished_name => {
        commonName => fact('networking.fqdn'),
      },
      extended_key_usage => ['clientAuth', 'serverAuth'];

    'etcd-client':
      distinguished_name => {
        commonName => fact('networking.fqdn'),
      };
  }

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
