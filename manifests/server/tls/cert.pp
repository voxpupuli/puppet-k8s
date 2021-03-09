define k8s::server::tls::cert(
  Hash[String, String] $distinguished_name,
  Stdlib::Unixpath $cert_path,
  Stdlib::Unixpath $ca_key,
  Stdlib::Unixpath $ca_cert,

  Enum['present', 'absent'] $ensure = $k8s::server::tls::ensure,

  Enum[2048, 4096, 8192] $key_bytes = $k8s::server::tls::key_bytes,
  Integer[1] $valid_days = $k8s::server::tls::valid_days,
  Array[Enum['clientAuth','serverAuth']] $extended_key_usage = ['clientAuth'],

  Array[
    Variant[
      Stdlib::Fqdn,
      Stdlib::IP::Address::Nosubnet,
    ]
  ] $addn_names = [],

  Stdlib::Unixpath $config = "${cert_path}/${title}.cnf",
  Stdlib::Unixpath $key = "${cert_path}/${title}.key",
  Stdlib::Unixpath $csr = "${cert_path}/${title}.key",
  Stdlib::Unixpath $cert = "${cert_path}/${title}.pem",

  String[1] $owner = 'root',
  String[1] $group = 'root',
) {
  $_ip_altnames = $addn_names.filter |$ip| {
    $ip =~ Stdlib::IP::Address
  }
  $_dns_altnames = ($addn_names - $_ip_altnames).filter |$dns| {
    $dns =~ Stdlib::Fqdn
  }

  file { $config:
    ensure  => $ensure,
    owner   => $owner,
    group   => $group,
    content => epp('k8s/server/tls/openssl.cnf.epp', {
      extended_key_usage => $extended_key_usage,
      distinguished_name => $distinguished_name,
      dns_altnames       => $_dns_altnames,
      ip_altnames        => $_ip_altnames,
    }),
    notify  => Exec["Create K8s ${title} CSR"],
  }

  if $ensure == 'present' {
    exec {
      default:
        path    => ['/usr/bin'],
        require => Package['openssl'];

      "Create K8s ${title} key":
        command => "openssl genrsa -out '${key}' ${key_bytes}",
        creates => $key,
        before  => File[$key];

      "Create K8s ${title} CSR":
        command => "openssl req -new -key '${key}' \
          -out '${csr}' -config '${$config}'",
        creates => $csr,
        notify  => Exec["Sign K8s ${title} cert"],
        before  => File[$csr];

      "Sign K8s ${title} cert":
        command => "openssl x509 -req -in '${csr}' \
          -CA '${ca_cert}' -CAkey '${ca_key}' -CAcreateserial \
          -out '${cert}' -days '${valid_days}' \
          -extensions v3_req -extfile '${config}'",
        creates => $cert,
        require => File[$ca_key, $ca_cert],
        before  => File[$cert];
    }
  }

  if !defined(File[$key]) {
    file { $key:
      ensure  => $ensure,
      owner   => $owner,
      group   => $group,
      mode    => '0640',
      replace => false,
    }
  }
  if !defined(File[$cert]) {
    file { $cert:
      ensure  => $ensure,
      owner   => $owner,
      group   => $group,
      replace => false,
    }
  }
  if !defined(File[$csr]) {
    file { $csr:
      ensure  => $ensure,
      owner   => $owner,
      group   => $group,
      replace => false,
    }
  }
}
