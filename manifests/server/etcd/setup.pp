class k8s::server::etcd::setup(
  Enum['present','absent'] $ensure = 'present',
  Enum['archive','package'] $install = 'archive',
  String[1] $package = 'etcd',
  String[1] $version = $k8s::etcd_version,
  String[1] $etcd_name = fact('hostname'),
  String[1] $fqdn = fact('networking.fqdn'),

  Stdlib::HTTPUrl $archive_template = 'https://storage.googleapis.com/etcd/v%{version}/etcd-v%{version}-%{kernel}-%{arch}.%{kernel_ext}',

  Stdlib::Unixpath $data_dir = "${etcd_name}.etcd",

  Enum['on','off','readonly'] $proxy = 'off',

  Array[Stdlib::HTTPUrl] $listen_client_urls = ['http://localhost:2379'],
  Array[Stdlib::HTTPUrl] $advertise_client_urls = ['http://localhost:2379'],
  Array[Stdlib::HTTPUrl] $listen_peer_urls = ['http://localhost:2380'],
  Array[Stdlib::HTTPUrl] $initial_advertise_peer_urls = ['http://localhost:2380'],

  Optional[Stdlib::Unixpath] $cert_file = undef,
  Optional[Stdlib::Unixpath] $key_file = undef,
  Optional[Stdlib::Unixpath] $trusted_ca_file = undef,
  Boolean $client_cert_auth = false,

  Optional[Stdlib::Unixpath] $peer_cert_file = undef,
  Optional[Stdlib::Unixpath] $peer_key_file = undef,
  Optional[Stdlib::Unixpath] $peer_trusted_ca_file = undef,
  Boolean $peer_client_cert_auth = false,

  Optional[Integer] $auto_compaction_retention = undef,
  Optional[Enum['existing', 'new']] $initial_cluster_state = undef,
  Optional[String[1]] $initial_cluster_token = undef,
  Optional[Array[Stdlib::HTTPUrl]] $initial_cluster = undef,
) {
  if $install == 'archive' {
    $_url = k8s::format_url($archive_template, {
      version => $version,
    })
    $_file = basename($_url)
    archive { $_file:
      ensure          => $ensure,
      source          => $_url,
      extract         => true,
      extract_command => 'tar xfz %s --strip-components=1 -C /usr/local/bin/',
      cleanup         => true,
      creates         => ['/usr/local/bin/etcd', '/usr/local/bin/etcdctl'],

      notify          => Service['etcd'],
    }

    if $ensure == 'absent' {
      file { ['/usr/local/bin/etcd', '/usr/local/bin/etcdctl']:
        ensure => 'absent',
      }
    }
  } else {
    package { 'etcd':
      ensure => $ensure,
      name   => $package,
    }
  }

  user { 'etcd':
    ensure => $ensure,
  }
  group { 'etcd':
    ensure  => $ensure,
    members => ['etcd'],
  }

  $_dir_ensure = $ensure ? {
    present => 'directory',
    default => 'absent',
  }
  file {
    default:
      ensure => $_dir_ensure;
    '/etc/etcd': ;
    '/var/lib/etcd':
      owner => 'etcd',
      group => 'etcd';
  }

  file {
    default:
      ensure => $ensure,
      owner  => 'root',
      group  => 'root';

    '/etc/etcd/etcd.conf':
      content => epp('server/etcd/etcd.conf.epp', {
        etcd_name                   => $etcd_name,
        data_dir                    => $data_dir,
        proxy                       => $proxy,
        listen_client_urls          => $listen_client_urls,
        advertise_client_urls       => $advertise_client_urls,
        listen_peer_urls            => $listen_peer_urls,
        initial_advertise_peer_urls => $initial_advertise_peer_urls,
        cert_file                   => $cert_file,
        key_file                    => $key_file,
        trusted_ca_file             => $trusted_ca_file,
        client_cert_auth            => $client_cert_auth,
        peer_cert_file              => $peer_cert_file,
        peer_key_file               => $peer_key_file,
        peer_trusted_ca_file        => $peer_trusted_ca_file,
        peer_client_cert_auth       => $peer_client_cert_auth,
        auto_compaction_retention   => $auto_compaction_retention,
        initial_cluster_state       => $initial_cluster_state,
        initial_cluster_token       => $initial_cluster_token,
      });

    # Separate out initial cluster configuration into a separate config file.
    # This avoids reloading the service when/if the initial cluster state changes,
    # as it only matters before the cluster has been established.
    '/etc/etcd/cluster.conf':
      content => epp('server/etcd/cluster.conf.epp', {
        initial_cluster => pick($initial_cluster, "${etcd_name}=${listen_peer_urls[0]}"),
      });
  }

  systemd::unit_file { 'etcd.service':
    ensure => $ensure,
    source => 'puppet:///modules/k8s/etcd.service',
    notify => Service['etcd'],
  }
  $_service_ensure = $ensure ? {
    present => 'running',
    default => 'stopped',
  }
  $_service_enable = $ensure ? {
    present => true,
    default => false,
  }
  service { 'etcd':
    ensure    => $_service_ensure,
    enable    => $_service_enable,
    require   => User['etcd'],
    subscribe => File['/etc/etcd/etcd.conf'],
  }
}
