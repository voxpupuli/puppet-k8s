# @summary Generates the necessary Kubernetes certificates for a server
class k8s::server::tls (
  K8s::Ensure $ensure   = 'present',
  Boolean $generate_ca  = $k8s::server::generate_ca,
  Boolean $manage_certs = $k8s::server::manage_certs,

  K8s::TLS_altnames $api_addn_names                  = [],
  String[1] $cluster_domain                          = $k8s::cluster_domain,
  Stdlib::IP::Address::Nosubnet $api_service_address = $k8s::api_service_address,

  Stdlib::Unixpath $cert_path = $k8s::server::cert_path,
  Integer[512] $key_bits      = 2048,
  Integer[1] $valid_days      = 10000,

  Stdlib::Unixpath $ca_key             = $k8s::server::ca_key,
  Stdlib::Unixpath $ca_cert            = $k8s::server::ca_cert,
  Stdlib::Unixpath $aggregator_ca_key  = $k8s::server::aggregator_ca_key,
  Stdlib::Unixpath $aggregator_ca_cert = $k8s::server::aggregator_ca_cert,
) {
  if $manage_certs or $ensure == 'absent' {
    if !defined(File[$cert_path]) {
      file { $cert_path:
        ensure => stdlib::ensure($ensure, 'directory'),
        owner  => 'kube',
        group  => 'kube',
      }
    }

    if $ensure == 'present' {
      ensure_packages(['openssl'])
      # Additional non-CA certs that should also only be generated on one node
      if $generate_ca {
        Package <| title == 'openssl' |>
        -> exec { 'K8s create service account private key':
          path    => $facts['path'],
          command => "openssl genrsa -out '${cert_path}/service-account.key' ${key_bits}; echo > '${cert_path}/service-account.pub'",
          unless  => "openssl pkey -in '${cert_path}/service-account.key' -text | grep '${key_bits} bit'",
          before  => [
            File["${cert_path}/service-account.key"],
            Exec['K8s get service account public key'],
          ],
        }
      }

      Package <| title == 'openssl' |>
      -> exec { 'K8s get service account public key':
        path    => $facts['path'],
        command => "openssl pkey -pubout -in '${cert_path}/service-account.key' -out '${cert_path}/service-account.pub'",
        unless  => "openssl pkey -pubin -in '${cert_path}/service-account.pub' -noout",
        before  => File["${cert_path}/service-account.pub"],
      }
    }

    # Generate K8s CA
    k8s::server::tls::ca {
      default:
        ensure     => $ensure,
        owner      => 'kube',
        group      => 'kube',
        key_bits   => $key_bits,
        valid_days => $valid_days,
        generate   => $generate_ca;

      'kube-ca':
        key  => $ca_key,
        cert => $ca_cert;

      'aggregator-ca':
        subject => '/CN=front-proxy',
        key     => $aggregator_ca_key,
        cert    => $aggregator_ca_cert;
    }

    k8s::server::tls::cert {
      default:
        ensure    => $ensure,
        cert_path => $cert_path,
        ca_key    => $ca_key,
        ca_cert   => $ca_cert,
        owner     => 'kube',
        group     => 'kube';

      'kube-apiserver':
        extended_key_usage => ['serverAuth'],
        # prevent undef value if ipv6 is turned off
        addn_names         => delete_undef_values(
          [
            'kubernetes',
            'kubernetes.default',
            'kubernetes.default.svc',
            "kubernetes.default.svc.${cluster_domain}",
            'kubernetes.service.discover',
            'localhost',
            fact('networking.hostname'),
            fact('networking.fqdn'),
            $api_service_address,
            $api_addn_names,
            $facts.get('networking.interfaces', {}).map |$_,$v| {
              ($v.get('bindings', []) + $v.get('bindings6', [])).map |$x| { $x.get('address') }
            }.filter |$x| { !empty($x) },
          ].flatten.sort.unique
        ),
        distinguished_name => {
          commonName => 'kube-apiserver',
        };

      'front-proxy-client':
        ca_key             => $aggregator_ca_key,
        ca_cert            => $aggregator_ca_cert,
        distinguished_name => {
          commonName => 'front-proxy-client',
        };

      'apiserver-kubelet-client':
        distinguished_name => {
          commonName       => 'apiserver-kubelet-client',
          organizationName => 'system:masters',
        };

      'kube-controller-manager':
        distinguished_name => {
          commonName => 'system:kube-controller-manager',
        };

      'kube-scheduler':
        distinguished_name => {
          commonName => 'system:kube-scheduler',
        };

      'kube-proxy':
        distinguished_name => {
          commonName => 'system:kube-proxy',
        };

      'node':
        extended_key_usage => ['serverAuth', 'clientAuth'],
        # prevent undef value if ipv6 is turned off
        addn_names         => delete_undef_values(
          [
            fact('networking.fqdn'),
            fact('networking.ip'),
            fact('networking.ip6'),
          ]
        ),
        distinguished_name => {
          organizationName => 'system:nodes',
          commonName       => "system:node:${fact('networking.fqdn')}",
        };

      'admin':
        distinguished_name => {
          organizationName => 'system:masters',
          commonName       => 'kube-admin',
        };
    }

    file {
      default:
        ensure => $ensure,
        owner  => 'kube',
        group  => 'kube';

      "${cert_path}/etcd-ca.pem":
        source => 'file:///var/lib/etcd/certs/client-ca.pem';

      "${cert_path}/etcd.pem":
        source => 'file:///var/lib/etcd/certs/etcd-client.pem';

      "${cert_path}/etcd.key":
        mode   => '0640',
        source => 'file:///var/lib/etcd/certs/etcd-client.key';
    }

    # Require either generation or user-provided etcd secrets before creating k8s copies
    K8s::Server::Tls::Ca <| title == 'etcd-client-ca' |> -> File["${cert_path}/etcd-ca.pem"]
    K8s::Server::Tls::Cert <| title == 'etcd-client' |> -> File["${cert_path}/etcd.pem"]
    K8s::Server::Tls::Cert <| title == 'etcd-client' |> -> File["${cert_path}/etcd.key"]

    File <| title == '/var/lib/etc/certs/client-ca.pem' |> -> File["${cert_path}/etcd-ca.pem"]
    File <| title == '/var/lib/etc/certs/etcd-client.pem' |> -> File["${cert_path}/etcd.pem"]
    File <| title == '/var/lib/etc/certs/etcd-client.key' |> -> File["${cert_path}/etcd.key"]

    if $generate_ca and !defined(File["${cert_path}/service-account.key"]) {
      file { "${cert_path}/service-account.key":
        ensure  => $ensure,
        owner   => kube,
        group   => kube,
        replace => false,
        mode    => '0600',
      }
    }
    if !defined(File["${cert_path}/service-account.pub"]) {
      file { "${cert_path}/service-account.pub":
        ensure  => $ensure,
        owner   => kube,
        group   => kube,
        replace => false,
        mode    => '0640',
      }
    }
  }
}
