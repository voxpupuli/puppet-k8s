class k8s::server::tls(
  Enum['present', 'absent'] $ensure = 'present',
  Boolean $generate_ca = $k8s::server::generate_ca,
  Boolean $manage_certs = $k8s::server::manage_certs,

  Array[
    Variant[
      Stdlib::Fqdn,
      Stdlib::IP::Address::Nosubnet,
    ]
  ] $api_addn_names = [],
  String[1] $cluster_domain = $k8s::cluster_domain,
  Stdlib::IP::Address::Nosubnet $api_service_address = $k8s::api_service_address,

  Stdlib::Unixpath $cert_path = $k8s::server::cert_path,
  Integer[512] $key_bits = 2048,
  Integer[1] $valid_days = 10000,

  Stdlib::Unixpath $ca_key = $k8s::server::ca_key,
  Stdlib::Unixpath $ca_cert = $k8s::server::ca_cert,
  Stdlib::Unixpath $aggregator_ca_key = $k8s::server::aggregator_ca_key,
  Stdlib::Unixpath $aggregator_ca_cert = $k8s::server::aggregator_ca_cert,
) {
  if $manage_certs or $ensure == 'absent' {
    ensure_packages(['openssl'])

    if !defined(File[$cert_path]) {
      file { $cert_path:
        ensure => ($ensure ? {
          present => directory,
          default => absent,
        }),
        owner  => 'kube',
        group  => 'kube',
      }
    }

    # Additional non-CA certs that should also only be generated on one node
    if $generate_ca {
      exec {
        default:
          path    => ['/usr/bin'],
          require => Package['openssl'];

        'Create service account private key':
          command => "openssl genrsa -out '${cert_path}/service-account.key' ${key_bits}",
          creates => "${cert_path}/service-account.key",
          before  => File["${cert_path}/service-account.key"];

        'Gets service account public key':
          command => "openssl pkey -pubout -in '${cert_path}/service-account.key' -out '${cert_path}/service-account.pub'",
          creates => "${cert_path}/service-account.pub",
          before  => File["${cert_path}/service-account.pub"];
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
        addn_names         => [
          'kubernetes',
          'kubernetes.default',
          'kubernetes.default.svc',
          "kubernetes.default.svc.${cluster_domain}",
          'kubernetes.service.discover',
          'localhost',
          fact('networking.hostname'),
          fact('networking.fqdn'),
          $api_service_address,
          '127.0.0.1',
          '::1',
          fact('networking.ip'),
          fact('networking.ip6'),
        ].unique(),
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
        addn_names         => [
          fact('networking.fqdn'),
          fact('networking.ip'),
          fact('networking.ip6'),
        ],
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
    if defined(Class['k8s::server::etcd::setup']) {
      Class['k8s::server::etcd::setup'] -> File["${cert_path}/etcd-ca.pem"]
      Class['k8s::server::etcd::setup'] -> File["${cert_path}/etcd.pem"]
      Class['k8s::server::etcd::setup'] -> File["${cert_path}/etcd.key"]
    }

    if !defined(File["${cert_path}/service-account.key"]) {
      file { "${cert_path}/service-account.key":
        owner   => kube,
        group   => kube,
        replace => false,
        mode    => '0600',
      }
    }
    if !defined(File["${cert_path}/service-account.pub"]) {
      file { "${cert_path}/service-account.pub":
        owner   => kube,
        group   => kube,
        replace => false,
        mode    => '0640',
      }
    }
  }
}
