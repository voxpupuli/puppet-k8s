# @summary Installs and configures an etcd instance
#
# @param advertise_client_urls The client urls to advertise
# @param archive_template The download url template for the etc archive
# @param auto_compaction_retention The auto compaction retention
# @param auto_tls Use auto tls
# @param binary_path path to the etcd binary
# @param cert_file path to the cert file
# @param client_cert_auth Use client cert auth
# @param data_dir path to the data dir
# @param ensure set ensure for installation or deinstallation
# @param etcd_name The etcd instance name
# @param fqdn fully qualified domain name
# @param gid The group system id
# @param group etcd system user group
# @param initial_advertise_peer_urls The peer urls to advertise
# @param initial_cluster The initial cluster
# @param initial_cluster_state The initial cluster state
# @param initial_cluster_token The initial cluster token
# @param install etcd installation method
# @param key_file path to the key file
# @param listen_client_urls The client urls to listen on
# @param listen_peer_urls The peer urls to listen on
# @param package etcd package name
# @param peer_auto_tls Use peer auto tls
# @param peer_cert_file path to the peer cert file
# @param peer_client_cert_auth Use peer client cert auth
# @param peer_key_file path to the peer key file
# @param peer_trusted_ca_file path to the peer trusted ca file
# @param proxy The proxy mode
# @param storage_path path to the working dir of etcd
# @param trusted_ca_file path to the trusted ca file
# @param uid The user system id
# @param user etcd system user
# @param version The ectd version to install
#
class k8s::server::etcd::setup (
  K8s::Ensure $ensure                = 'present',
  Enum['archive','package'] $install = 'archive',
  String[1] $package                 = 'etcd',
  String[1] $version                 = $k8s::etcd_version,
  String[1] $etcd_name               = $facts['networking']['hostname'],
  String[1] $fqdn                    = $facts['networking']['fqdn'],

  Stdlib::HTTPUrl $archive_template = 'https://storage.googleapis.com/etcd/v%{version}/etcd-v%{version}-%{kernel}-%{arch}.%{kernel_ext}',

  String[1] $data_dir = "${etcd_name}.etcd",

  Enum['on','off','readonly'] $proxy = 'off',

  Array[Stdlib::HTTPUrl] $listen_client_urls          = ['https://[::]:2379'],
  Array[Stdlib::HTTPUrl] $advertise_client_urls       = ["https://${fqdn}:2379"],
  Array[Stdlib::HTTPUrl] $listen_peer_urls            = ['https://[::]:2380'],
  Array[Stdlib::HTTPUrl] $initial_advertise_peer_urls = ["https://${fqdn}:2380"],

  Optional[Stdlib::Unixpath] $peer_cert_file       = undef,
  Optional[Stdlib::Unixpath] $peer_key_file        = undef,
  Optional[Stdlib::Unixpath] $peer_trusted_ca_file = undef,
  Optional[Boolean] $peer_auto_tls                 = undef,
  Boolean $peer_client_cert_auth                   = false,

  Optional[Stdlib::Unixpath] $cert_file       = undef,
  Optional[Stdlib::Unixpath] $key_file        = undef,
  Optional[Stdlib::Unixpath] $trusted_ca_file = undef,
  Optional[Boolean] $auto_tls                 = undef,
  Boolean $client_cert_auth                   = false,

  Optional[Integer] $auto_compaction_retention             = undef,
  Optional[Enum['existing', 'new']] $initial_cluster_state = undef,
  Optional[String[1]] $initial_cluster_token               = undef,
  Array[String[1]] $initial_cluster                        = [],

  Optional[Stdlib::Unixpath] $binary_path = undef,
  Stdlib::Unixpath $storage_path          = '/var/lib/etcd',
  String[1] $user                         = 'etcd',
  String[1] $group                        = 'etcd',
  Optional[Integer[0, 65535]] $uid        = undef,
  Optional[Integer[0, 65535]] $gid        = undef,
) {
  if defined(Class['k8s::server::etcd']) {
    $_k8s_server_etcd_self_signed_tls = $k8s::server::etcd::self_signed_tls
    $_k8s_server_etcd_manage_certs = $k8s::server::etcd::manage_certs
  } else {
    $_k8s_server_etcd_self_signed_tls = lookup('k8s::server::etcd::self_signed_tls', default_value => undef)
    $_k8s_server_etcd_manage_certs = lookup('k8s::server::etcd::manage_certs', default_value => undef)
  }
  $_peer_auto_tls = pick($peer_auto_tls, $_k8s_server_etcd_self_signed_tls, false)
  $_auto_tls = pick($auto_tls, $_k8s_server_etcd_self_signed_tls, false)

  if $install == 'archive' {
    $_url  = k8s::format_url($archive_template, { version => $version, })
    $_file = basename($_url)
    $_target = "/opt/k8s/etcd-${version}";
    $_tarball_target = '/opt/k8s/archives';

    file { $_target:
      ensure => stdlib::ensure($ensure, 'directory'),
    }

    archive { 'etcd':
      ensure          => $ensure,
      path            => "${_tarball_target}/${_file}",
      source          => $_url,
      extract         => true,
      extract_command => 'tar xfz %s --strip-components=1',
      extract_path    => $_target,
      cleanup         => true,
      creates         => ["${_target}/etcd", "${_target}/etcdctl"],
    }

    file { '/usr/local/bin/etcd':
      ensure  => stdlib::ensure($ensure, 'link'),
      mode    => '0755',
      replace => true,
      target  => "${_target}/etcd",
      require => Archive['etcd'],
      notify  => Service['etcd'],
    }

    file { '/usr/local/bin/etcdctl':
      ensure  => stdlib::ensure($ensure, 'link'),
      mode    => '0755',
      replace => true,
      target  => "${_target}/etcdctl",
      require => Archive['etcd'],
    }

    group { $group:
      ensure => $ensure,
      system => true,
      gid    => $gid,
    }

    user { $user:
      ensure     => $ensure,
      comment    => 'etcd user',
      gid        => $gid,
      home       => $storage_path,
      managehome => false,
      shell      => (fact('os.family') ? {
          'Debian' => '/usr/sbin/nologin',
          default  => '/sbin/nologin',
      }),
      system     => true,
      uid        => $uid,
    }
  } else {
    package { $package:
      ensure => stdlib::ensure($ensure, 'package'),
    }
  }

  file {
    default:
      ensure => stdlib::ensure($ensure, 'directory');

    '/etc/etcd': ;
    $storage_path:
      owner => $user,
      group => $group;
  }

  # Use generated certs by default
  if !$_k8s_server_etcd_self_signed_tls and $_k8s_server_etcd_manage_certs {
    $_dir                   = "${storage_path}/certs"
    $_cert_file             = pick($cert_file, "${_dir}/etcd-server.pem")
    $_key_file              = pick($key_file, "${_dir}/etcd-server.key")
    $_trusted_ca_file       = pick($trusted_ca_file, "${_dir}/client-ca.pem")
    $_client_cert_auth      = pick($client_cert_auth, true)
    $_peer_cert_file        = pick($peer_cert_file, "${_dir}/etcd-peer.pem")
    $_peer_key_file         = pick($peer_key_file, "${_dir}/etcd-peer.key")
    $_peer_trusted_ca_file  = pick($peer_trusted_ca_file, "${_dir}/peer-ca.pem")
    $_peer_client_cert_auth = pick($peer_client_cert_auth, true)
  } else {
    $_cert_file             = $cert_file
    $_key_file              = $key_file
    $_trusted_ca_file       = $trusted_ca_file
    $_client_cert_auth      = $client_cert_auth
    $_peer_cert_file        = $peer_cert_file
    $_peer_key_file         = $peer_key_file
    $_peer_trusted_ca_file  = $peer_trusted_ca_file
    $_peer_client_cert_auth = $peer_client_cert_auth
  }

  $_initial_cluster = [
    "${etcd_name}=${initial_advertise_peer_urls[0]}"
  ] + $initial_cluster

  file {
    default:
      ensure => stdlib::ensure($ensure, 'file'),
      owner  => 'root',
      group  => 'root';

    '/etc/etcd/etcd.conf':
      content => epp('k8s/server/etcd/etcd.conf.epp', {
          etcd_name                   => $etcd_name,
          data_dir                    => $data_dir,
          proxy                       => $proxy,
          listen_client_urls          => $listen_client_urls,
          advertise_client_urls       => $advertise_client_urls,
          listen_peer_urls            => $listen_peer_urls,
          initial_advertise_peer_urls => $initial_advertise_peer_urls,
          cert_file                   => $_cert_file,
          key_file                    => $_key_file,
          trusted_ca_file             => $_trusted_ca_file,
          client_cert_auth            => $_client_cert_auth,
          auto_tls                    => $_auto_tls,
          peer_cert_file              => $_peer_cert_file,
          peer_key_file               => $_peer_key_file,
          peer_trusted_ca_file        => $_peer_trusted_ca_file,
          peer_client_cert_auth       => $_peer_client_cert_auth,
          peer_auto_tls               => $_peer_auto_tls,
          auto_compaction_retention   => $auto_compaction_retention,
          initial_cluster_state       => $initial_cluster_state,
          initial_cluster_token       => $initial_cluster_token,
      }),
      notify  => Service['etcd'];

    # Separate out initial cluster configuration into a separate config file.
    # This avoids reloading the service when/if the initial cluster state changes,
    # as it only matters before the cluster has been established.
    '/etc/etcd/cluster.conf':
      content => epp('k8s/server/etcd/cluster.conf.epp', {
          initial_cluster => $_initial_cluster,
      });
  }

  if $install == 'package' {
    $_binary_path    = pick($binary_path, '/usr/bin/etcd')
    $service_require = Package[$package]
  } else {
    $_binary_path    = pick($binary_path, '/usr/local/bin/etcd')
    $service_require = User[$user]
  }

  systemd::unit_file { 'etcd.service':
    ensure  => $ensure,
    content => epp('k8s/etcd.service.epp', {
        binary_path  => $_binary_path,
        workdir_path => $storage_path,
        user         => $user,
    }),
    notify  => Service['etcd'],
  }

  service { 'etcd':
    ensure    => stdlib::ensure($ensure, 'service'),
    enable    => true,
    require   => $service_require,
    subscribe => File['/etc/etcd/etcd.conf'],
  }
}
