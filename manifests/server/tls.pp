class k8s::server::tls(
  Enum['present', 'absent'] $ensure = 'present',
  Boolean $generate_ca = false,
  Boolean $manage_certs = $k8s::server::manage_certs,

  Array[
    Variant[
      Stdlib::Fqdn,
      Stdlib::IP::Address::Nosubnet,
    ]
  ] $api_addn_names = [],
  String[1] $cluster_domain = $k8s::cluster_domain,
  Stdlib::IP::Address::Nosubnet $api_address = $k8s::api_address,

  Stdlib::Unixpath $cert_path = '/srv/kubernetes/certs',
  Enum[2048, 4096, 8192] $key_bytes = 2048,
  Integer[1] $valid_days = 10000,

  Stdlib::Unixpath $ca_key = "${cert_path}/ca.key",
  Stdlib::Unixpath $ca_cert = "${cert_path}/ca.pem",
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

    # Generate K8s CA
    k8s::server::tls::ca { 'kube-ca':
      ensure   => $ensure,
      key      => $ca_key,
      cert     => $ca_cert,
      owner    => 'kube',
      group    => 'kube',
      generate => $generate_ca,
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
        addn_names         => [
          'kubernetes',
          'kubernetes.default',
          'kubernetes.default.svc',
          "kubernetes.default.svc.${cluster_domain}",
          'kubernetes.service.discover',
          fact('networking.fqdn'),
          $api_address,
          fact('networking.ip'),
          fact('networking.ip6'),
        ],
        distinguished_name => {
          commonName => 'kube-apiserver',
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
        extended_key_usage => ['clientAuth', 'serverAuth'],
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
  }
}
