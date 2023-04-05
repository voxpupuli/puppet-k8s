# @summary Generates a TLS CA
define k8s::server::tls::ca (
  K8s::Ensure $ensure = present,

  Stdlib::Unixpath $key,
  Stdlib::Unixpath $cert,
  String[1] $subject = "/CN=${title}",

  String[1] $owner = 'root',
  String[1] $group = 'root',

  Integer[512] $key_bits = 2048,
  Integer[1] $valid_days = 10000,
  Boolean $generate      = true,
) {
  if $ensure == 'present' and $generate {
    Package <| title == 'openssl' |>
    -> exec {
      default:
        path => pick($facts['path'], '/usr/bin:/bin');

      "Create ${title} CA key":
        command => "openssl genrsa -out '${key}' ${key_bits}",
        unless  => "openssl pkey -in '${key}' -text | grep '${key_bits} bit'",
        before  => File[$key];

      "Create ${title} CA cert":
        command   => "openssl req -x509 -new -nodes -key '${key}' \
          -days '${valid_days}' -out '${cert}' -subj '${subject}'",
        unless    => "openssl x509 -CA '${cert}' -CAkey '${key}' -in '${cert}' -noout",
        subscribe => Exec["Create ${title} CA key"],
        require   => File[$key],
        before    => File[$cert];
    }
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
