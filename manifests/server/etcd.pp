# @summary Sets up an etcd cluster node
#
# @param addn_names additional names for certificates
# @param cert_path path to cert files
# @param client_ca_cert
# @param client_ca_key
# @param cluster_name name of the etcd cluster for searching its nodes in the puppetdb
# @param ensure set ensure for installation or deinstallation
# @param firewall_type define the type of firewall to use
# @param generate_ca whether to generate a own ca or not
# @param manage_certs whether to manage certs or not
# @param manage_firewall whether to manage firewall or not
# @param manage_members whether to manage the ectd cluster member joining or not
# @param manage_setup whether to manage the setup of etcd or not
# @param peer_ca_cert
# @param peer_ca_key
# @param puppetdb_discovery_tag enable puppetdb resource searching
# @param self_signed_tls
# @param version version of ectd to install
#
class k8s::server::etcd (
  K8s::Ensure $ensure = 'present',
  String[1] $version  = pick($k8s::etcd_version, '3.5.1'),

  Boolean $manage_setup             = true,
  Boolean $manage_firewall          = false,
  Boolean $manage_members           = false,
  String[1] $cluster_name           = pick($k8s::server::etcd_cluster_name, 'default'),
  String[1] $puppetdb_discovery_tag = pick($k8s::server::puppetdb_discovery_tag, $cluster_name),

  Boolean $self_signed_tls = false,
  Boolean $manage_certs    = true,
  Boolean $generate_ca     = false,

  K8s::TLS_altnames $addn_names = [],

  Stdlib::Unixpath $cert_path      = '/var/lib/etcd/certs',
  Stdlib::Unixpath $peer_ca_key    = "${cert_path}/peer-ca.key",
  Stdlib::Unixpath $peer_ca_cert   = "${cert_path}/peer-ca.pem",
  Stdlib::Unixpath $client_ca_key  = "${cert_path}/client-ca.key",
  Stdlib::Unixpath $client_ca_cert = "${cert_path}/client-ca.pem",

  Optional[K8s::Firewall] $firewall_type = $k8s::server::firewall_type,
  String[1] $user  = 'etcd',
  String[1] $group = 'etcd',
) {
  if (!$self_signed_tls and $manage_certs) or $ensure == 'absent' {
    if !defined(File[$cert_path]) {
      file { $cert_path:
        ensure => stdlib::ensure($ensure, 'directory'),
        owner  => $user,
        group  => $group,
      }
    }

    $_addn_names = delete_undef_values( # prevent undef value if ipv6 is turned off
      [
        fact('networking.hostname'),
        fact('networking.fqdn'),
        fact('networking.ip'),
        fact('networking.ip6'),
        'localhost',
        '127.0.0.1',
        '::1',
      ] + $addn_names
    ).unique

    k8s::server::tls::ca {
      default:
        ensure   => $ensure,
        owner    => $user,
        group    => $group,
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
        owner     => $user,
        group     => $group,
        cert_path => $cert_path;

      'etcd-server':
        ca_key             => $client_ca_key,
        ca_cert            => $client_ca_cert,
        addn_names         => $_addn_names,
        distinguished_name => {
          commonName => fact('networking.fqdn'),
        },
        extended_key_usage => ['serverAuth'];

      'etcd-peer':
        ca_key             => $peer_ca_key,
        ca_cert            => $peer_ca_cert,
        addn_names         => $_addn_names,
        distinguished_name => {
          commonName => fact('networking.fqdn'),
        },
        extended_key_usage => ['serverAuth', 'clientAuth'];

      'etcd-client':
        ca_key             => $client_ca_key,
        ca_cert            => $client_ca_cert,
        distinguished_name => {
          commonName => 'etcd client',
        };
    }
  }

  if $manage_setup and !$manage_members {
    include k8s::server::etcd::setup
  }

  if $ensure == 'present' and $manage_members {
    # Needs the PuppetDB terminus installed
    $pql_query = [
      'resources[certname,parameters] {',
      '  type = \'Class\' and',
      '  title = \'K8s::Server::Etcd::Setup\' and',
      '  nodes {',
      '    resources {',
      '      type = \'Class\' and',
      '      title = \'K8s::Server::Etcd\' and',
      "      parameters.cluster_name = '${cluster_name}' and",
      "      parameters.puppetdb_discovery_tag = '${puppetdb_discovery_tag}' and",
      "      certname != '${trusted[certname]}'",
      '    }',
      '  }',
      '  order by certname }',
    ].join(' ')

    $cluster_nodes = puppetdb_query($pql_query)
    if $manage_setup {
      class { 'k8s::server::etcd::setup':
        initial_cluster       => $cluster_nodes.map |$node| {
          "${node['parameters']['etcd_name']}=${node['parameters']['initial_advertise_peer_urls'][0]}"
        },
        initial_cluster_state => ($cluster_nodes.size() ? {
            0       => 'new',
            default => 'existing',
        }),
      }
    }

    $cluster_nodes.each |$node| {
      k8s::server::etcd::member { $node['parameters']['etcd_name']:
        peer_urls    => $node['parameters']['initial_advertise_peer_urls'],
        cluster_urls => ['https://localhost:2379'],
        cluster_ca   => $client_ca_cert,
        cluster_cert => "${cert_path}/etcd-client.pem",
        cluster_key  => "${cert_path}/etcd-client.key",
      }
    }
  }

  if $manage_firewall {
    if $facts['firewalld_version'] {
      $_firewall_type = pick($firewall_type, 'firewalld')
    } else {
      $_firewall_type = pick($firewall_type, 'iptables')
    }

    case $_firewall_type {
      'firewalld' : {
        firewalld_service {
          default:
            ensure => $ensure,
            zone   => 'public';

          'Allow etcd server access':
            service => 'etcd-server';

          'Allow etcd client access':
            service => 'etcd-client';
        }
      }
      'iptables': {
        include firewall

        firewall { '100 allow etcd server access':
          dport  => 2379,
          proto  => 'tcp',
          action => 'accept',
        }
        firewall { '100 allow etcd client access':
          dport  => 2380,
          proto  => 'tcp',
          action => 'accept',
        }
      }
      default: {}
    }
  }
}
