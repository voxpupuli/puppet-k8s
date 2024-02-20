# Class: k8s::install::cni_plugins
#
# @summary manages the installation of the cni plugins
#
# @param ensure set ensure for installation or deinstallation
# @param method installation method
# @param version sets the version to use
# @param download_url_template template string for the cni_plugins download url
#
class k8s::install::cni_plugins (
  K8s::Ensure $ensure              = $k8s::ensure,
  String[1] $version               = 'v1.2.0',
  String[1] $method                = $k8s::native_packaging,
  String[1] $download_url_template = 'https://github.com/containernetworking/plugins/releases/download/%{version}/cni-plugins-linux-%{arch}-%{version}.tgz',
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
      $_url = k8s::format_url($download_url_template, {
          version => $version,
      })

      file { '/opt/cni/bin':
        ensure => directory,
      }

      archive { 'cni-plugins':
        ensure       => $ensure,
        path         => "/tmp/cni-plugins-linux-${version}.tgz",
        source       => $_url,
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
