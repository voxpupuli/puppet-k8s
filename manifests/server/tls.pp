class k8s::server::tls(
  Enum['present', 'absent'] $ensure = 'present',
  Boolean $generate_ca = $k8s::server::generate_ca,

  Array[
    Variant[
      Stdlib::Fqdn,
      Stdlib::IP::Address::Nosubnet,
    ]
  ] $api_addn_names = [],
  Hash[String, String] $distinguished_name = { },
  String[1] $cluster_domain = $k8s::cluster_domain,
  Stdlib::IP::Address::Nosubnet $api_address = $k8s::api_address,

  Stdlib::Unixpath $cert_path = '/srv/kubernetes/certs',
  Enum[2048, 4096, 8192] $key_bytes = 2048,
  Integer[1] $valid_days = 10000,

  Stdlib::Unixpath $ca_key = "${cert_path}/ca.key",
  Stdlib::Unixpath $ca_cert = "${cert_path}/ca.pem",
) {
  ensure_packages(['openssl'])

  # Generate CA - if necessary
  include k8s::server::tls::ca

  k8s::server::tls::cert { 'apiserver':
    config             => "${cert_path}/api.cnf",
    key                => "${cert_path}/api.key",
    csr                => "${cert_path}/api.csr",
    cert               => "${cert_path}/api.pem",

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
    },
  }

  k8s::server::tls::cert { 'controller-manager':
    config             => "${cert_path}/controller-manager.cnf",
    key                => "${cert_path}/controller-manager.key",
    csr                => "${cert_path}/controller-manager.csr",
    cert               => "${cert_path}/controller-manager.pem",

    distinguished_name => {
      commonName => 'system:kube-controller-manager',
    },
  }
  k8s::server::tls::cert { 'scheduler':
    config             => "${cert_path}/scheduler.cnf",
    key                => "${cert_path}/scheduler.key",
    csr                => "${cert_path}/scheduler.csr",
    cert               => "${cert_path}/scheduler.pem",

    distinguished_name => {
      commonName => 'system:kube-scheduler',
    },
  }
  k8s::server::tls::cert { 'proxy':
    config             => "${cert_path}/proxy.cnf",
    key                => "${cert_path}/proxy.key",
    csr                => "${cert_path}/proxy.csr",
    cert               => "${cert_path}/proxy.pem",

    distinguished_name => {
      commonName => 'system:kube-proxy',
    },
  }
  k8s::server::tls::cert { 'node':
    config             => "${cert_path}/node.cnf",
    key                => "${cert_path}/node.key",
    csr                => "${cert_path}/node.csr",
    cert               => "${cert_path}/node.pem",
    extended_key_usage => ['clientAuth', 'serverAuth'],

    addn_names         => [
      fact('networking.fqdn'),
      fact('networking.ip'),
      fact('networking.ip6'),
    ],

    distinguished_name => {
      organizationName => 'system:nodes',
      commonName       => "system:node:${fact('networking.fqdn')}",
    },
  }
  k8s::server::tls::cert { 'admin':
    config             => "${cert_path}/admin.cnf",
    key                => "${cert_path}/admin.key",
    csr                => "${cert_path}/admin.csr",
    cert               => "${cert_path}/admin.pem",

    distinguished_name => {
      organizationName => 'system:masters',
      commonName       => 'kube-admin',
    },
  }
}
