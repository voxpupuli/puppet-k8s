# @summary Generates a TLS CA
#
# @param key The path to the CA key
# @param cert The path to the CA certificate
# @param ensure Whether the CA should be present or absent
# @param subject The subject of the CA certificate
# @param owner The owner of the CA key and certificate
# @param group The group of the CA key and certificate
# @param key_bits The number of bits in the CA key
# @param valid_days The number of days the CA certificate is valid
# @param generate Whether to generate the CA key and certificate
#
define k8s::server::tls::ca (
  Stdlib::Unixpath $key,
  Stdlib::Unixpath $cert,
  K8s::Ensure $ensure = present,

  String[1] $subject = "/CN=${title}",

  String[1] $owner = 'root',
  String[1] $group = 'root',

  Integer[512] $key_bits = 2048,
  Integer[1] $valid_days = 10000,
  Boolean $generate      = true,
) {
  if $ensure == 'present' {
    if $generate {
      Package <| title == 'openssl' |>
      -> exec { "Create ${title} CA key":
        command => "openssl genrsa -out '${key}' ${key_bits}",
        unless  => "openssl pkey -in '${key}' -text | grep '${key_bits} bit'",
        path    => $facts['path'],
        before  => File[$key],
      }
    }

    Package <| title == 'openssl' |>
    -> exec { "Create ${title} CA cert":
      command   => "openssl req -x509 -new -nodes -key '${key}' \
        -days '${valid_days}' -out '${cert}' -subj '${subject}'",
      unless    => "openssl x509 -CA '${cert}' -CAkey '${key}' -in '${cert}' -noout -set_serial 00",
      path      => $facts['path'],
      subscribe => File[$key],
      before    => File[$cert],
    }

    # Add a subscription if CA key is generated
    Exec <| title == "Create ${title} CA key" |> ~> Exec["Create ${title} CA cert"]
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
      mode    => '0644',
      replace => false,
    }
  }
}
