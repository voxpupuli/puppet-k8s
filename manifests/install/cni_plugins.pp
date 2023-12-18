# Class: k8s::install::cni_plugins
#
# @summary manages the installation of the cni plugins
#
# @param arch sets the arch to use for binary download
# @param ensure set ensure for installation or deinstallation
# @param method installation method
# @param version sets the version to use
#
class k8s::install::cni_plugins (
  K8s::Ensure $ensure = $k8s::ensure,
  String[1] $version  = 'v1.2.0',
  String[1] $arch     = 'amd64',
  String[1] $method   = $k8s::native_packaging,
) {
  file {
    default:
      ensure => directory;

    '/etc/cni': ;
    '/etc/cni/net.d': ;
    '/opt/cni': ;
  }

  case $method {
    'tarball', 'loose': {
      file { '/opt/cni/bin':
        ensure => directory,
      }

      archive { 'cni-plugins':
        ensure       => $ensure,
        path         => "/tmp/cni-plugins-linux--${arch}-${version}.tgz",
        source       => "https://github.com/containernetworking/plugins/releases/download/${version}/cni-plugins-linux-${arch}-${version}.tgz",
        extract      => true,
        extract_path => '/opt/cni/bin',
        creates      => '/opt/cni/bin/bridge',
        cleanup      => true,
        require      => File['/opt/cni/bin'],
      }
    }
    'package':{
      ensure_packages(['containernetworking-plugins',])

      file { '/opt/cni/bin':
        ensure  => link,
        target  => '/usr/lib/cni',
        require => Package['containernetworking-plugins'],
      }

      if $k8s::manage_repo {
        Class['k8s::repo'] -> Package['containernetworking-plugins']
      }
    }
    default: {
      fail("install method ${method} not supported")
    }
  }
}
