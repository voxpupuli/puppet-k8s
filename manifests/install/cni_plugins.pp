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
      file { '/opt/cni-plugins':
        ensure  => stdlib::ensure($ensure, 'directory'),
        purge   => true,
        recurse => true,
        force   => true,
      }

      $_url = k8s::format_url($download_url_template, {
          version => $version,
      })
      $_target = "/opt/cni-plugins/${version}";
      $_tarball_target = '/opt/cni-plugins/archives';

      file { $_target:
        ensure  => stdlib::ensure($ensure, 'directory'),
      }

      file { $_tarball_target:
        ensure  => stdlib::ensure($ensure, 'directory'),
        purge   => true,
        recurse => true,
      }

      archive { 'cni-plugins':
        ensure       => $ensure,
        path         => "${_tarball_target}/cni-plugins-linux-${version}.tgz",
        source       => $_url,
        extract      => true,
        extract_path => $_target,
        creates      => "${_target}/bridge",
        cleanup      => true,
      }

      file { '/opt/cni/bin':
        ensure  => stdlib::ensure($ensure, 'link'),
        mode    => '0755',
        replace => true,
        force   => true,
        target  => $_target,
        require => Archive['cni-plugins'],
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
