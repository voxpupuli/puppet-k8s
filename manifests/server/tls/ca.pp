define k8s::server::tls::ca(
  Stdlib::Unixpath $key,
  Stdlib::Unixpath $cert,
  String[1] $subject = "/CN=${title}",

  String[1] $owner = 'kube',
  String[1] $group = 'kube',

  Enum['present', 'absent'] $ensure = $k8s::server::tls::ensure,

  Enum[2048, 4096, 8192] $key_bytes = $k8s::server::tls::key_bytes,
  Integer[1] $valid_days = $k8s::server::tls::valid_days,

) {
  if $ensure == 'present' {
    exec {
      default:
        path    => ['/usr/bin'],
        require => Package['openssl'];

      "Create ${title} CA key":
        command => "openssl genrsa -out '${key}' ${key_bytes}",
        creates => $key,
        before  => File[$key];

      "Create ${title} CA cert":
        command => "openssl req -x509 -new -nodes -key '${key}' \
          -days '${valid_days}' -out '${cert}' -subj '${subject}'",
        creates => $cert,
        require => Exec['Create K8s CA key'],
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
      mode    => '0644',
      replace => false,
    }
  }
}
