# @summary Generates and signs a TLS certificate
#
# @param addn_names The additional names for the certificate
# @param ca_cert The path to the CA certificate
# @param ca_key The path to the CA key
# @param cert The path to the certificate file
# @param cert_path The path to the directory where the certificate will be stored
# @param config The path to the OpenSSL config file
# @param csr The path to the CSR file
# @param distinguished_name The distinguished name for the certificate
# @param ensure Whether the certificate should be present or absent
# @param extended_key_usage The extended key usage for the certificate
# @param group The group of the certificate files
# @param key The path to the key file
# @param key_bits The number of bits in the key
# @param owner The owner of the certificate files
# @param valid_days The number of days the certificate should be valid
#
define k8s::server::tls::cert (
  Hash[String, String] $distinguished_name,
  Stdlib::Unixpath $cert_path,
  Stdlib::Unixpath $ca_key,
  Stdlib::Unixpath $ca_cert,

  K8s::Ensure $ensure = present,

  Integer[512] $key_bits                      = 2048,
  Integer[1] $valid_days                      = 10000,
  K8s::Extended_key_usage $extended_key_usage = ['clientAuth'],

  K8s::TLS_altnames $addn_names = [],

  Stdlib::Unixpath $config = "${cert_path}/${title}.cnf",
  Stdlib::Unixpath $key = "${cert_path}/${title}.key",
  Stdlib::Unixpath $csr = "${cert_path}/${title}.csr",
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
  }
  ~> Exec <| title == "Create K8s ${title} CSR" |>

  if $ensure == 'present' {
    Package <| title == 'openssl' |>
    -> exec {
      default:
        path => $facts['path'];

      "Create K8s ${title} key":
        command => "openssl genrsa -out '${key}' ${key_bits}; echo > '${cert}'",
        unless  => "openssl pkey -in '${key}' -text | grep '${key_bits} bit'",
        before  => File[$key],
        notify  => Exec["Create K8s ${title} CSR"];

      "Create K8s ${title} CSR":
        command     => "openssl req -new -key '${key}' \
          -out '${csr}' -config '${$config}'; echo > '${cert}'",
        refreshonly => true,
        notify      => Exec["Sign K8s ${title} cert"],
        require     => File[$key],
        before      => File[$csr];

      "Sign K8s ${title} cert":
        command => "openssl x509 -req -in '${csr}' \
          -CA '${ca_cert}' -CAkey '${ca_key}' -CAcreateserial \
          -out '${cert}' -days '${valid_days}' \
          -extensions v3_req -extfile '${config}'",
        unless  => "openssl verify -CAfile '${ca_cert}' '${cert}'",
        require => [
          File[$csr],
          File[$key],
        ],
        before  => File[$cert];
    }
    File <| title == $ca_key or title == $ca_cert |> -> Exec["Sign K8s ${title} cert"]
  }

  if !defined(File[$key]) {
    file { $key:
      ensure  => $ensure,
      owner   => $owner,
      group   => $group,
      mode    => '0600',
      replace => false,
    }
  }
  if !defined(File[$cert]) {
    file { $cert:
      ensure  => $ensure,
      owner   => $owner,
      group   => $group,
      mode    => '0640',
      replace => false,
    }
  }
  if !defined(File[$csr]) {
    file { $csr:
      ensure  => $ensure,
      owner   => $owner,
      group   => $group,
      mode    => '0640',
      replace => false,
    }
  }
}
