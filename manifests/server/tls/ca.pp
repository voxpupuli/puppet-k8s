class k8s::server::tls::ca(
  Enum['present', 'absent'] $ensure = $k8s::server::tls::ensure,
  Boolean $generate_ca = $k8s::server::tls::generate_ca,

  Enum[2048, 4096, 8192] $key_bytes = $k8s::server::tls::key_bytes,
  Integer[1] $valid_days = $k8s::server::tls::valid_days,
  String[1] $subject = '/CN=kube-ca',

  Stdlib::Unixpath $key = $k8s::server::tls::ca_key,
  Stdlib::Unixpath $cert = $k8s::server::tls::ca_cert,
) {
  if $generate_ca and $ensure == 'present' {
    exec {
      default:
        path     => ['/usr/bin'],
        requires => Package['openssl'];

      'Create K8s CA key':
        command => "openssl genrsa -out '${key}' ${key_bytes}",
        creates => $key,
        before  => File[$key];

      'Create K8s CA cert':
        command  => "openssl req -x509 -new -nodes -key '${key}' \
          -days '${valid_days}' -out '${cert}' -subj '${subject}'",
        creates  => $cert,
        requires => Exec['Create K8s CA key'],
        before   => File[$cert];
    }
  }

  if !defined(File[$key]) {
    file { $key:
      ensure  => $ensure,
      owner   => 'kube',
      group   => 'kube',
      mode    => '0640',
      replace => false,
    }
  }
  if !defined(File[$cert]) {
    file { $cert:
      ensure  => $ensure,
      owner   => 'kube',
      group   => 'kube',
      mode    => '0644',
      replace => false,
    }
  }
}
