class k8s::server::etcd(
  Enum['present', 'absent'] $ensure = 'present',

  Boolean $manage_members = false,
  String[1] $cluster_name = 'default',

  Boolean $self_signed_tls = false,
  Boolean $manage_certs = $k8s::server::manage_certs,
  Boolean $generate_ca = false,
  Stdlib::Unixpath $cert_path = '/var/lib/etcd/certs',
  Stdlib::Unixpath $peer_ca_key = "${cert_path}/peer-ca.key",
  Stdlib::Unixpath $peer_ca_cert = "${cert_path}/peer-ca.pem",
  Stdlib::Unixpath $client_ca_key = "${cert_path}/client-ca.key",
  Stdlib::Unixpath $client_ca_cert = "${cert_path}/client-ca.pem",
) {
  if (!$self_signed_tls and $manage_certs) or $ensure == 'absent' {
    if !defined(File[$cert_path]) {
      file { $cert_path:
        ensure => ($ensure ? {
          present => directory,
          default => absent,
        }),
        owner  => 'etcd',
        group  => 'etcd',
      }
    }

    k8s::server::tls::ca {
      default:
        ensure   => $ensure,
        owner    => 'etcd',
        group    => 'etcd',
        generate => $generate_ca;

      'etcd-peer-ca':
        key  => $peer_ca_key,
        cert => $peer_ca_cert;

      'etcd-client-ca':
        key  => $client_ca_key,
        cert => $client_ca_cert;
    }

    k8s::server::tls::cert {
      default:
        ensure    => $ensure,
        owner     => 'etcd',
        group     => 'etcd',
        cert_path => $cert_path;

      'etcd-peer':
        ca_key             => $peer_ca_key,
        ca_cert            => $peer_ca_cert,
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
        ca_key             => $client_ca_key,
        ca_cert            => $client_ca_cert,
        distinguished_name => {
          commonName => fact('networking.fqdn'),
        };
    }
  }

  include k8s::server::etcd::setup

  if $ensure == 'present' and $manage_members {
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