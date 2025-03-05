# @summary Manages the installation of CNI plugins
#
# @param ensure Set ensure for installation or deinstallation
# @param method The installation method to use
# @param version The version of CNI plugins to install - if applicable
# @param download_url_template Template string for the cni_plugins download url
# @param package_name Package name for the CNI plugins, will use OS default if omitted
#
class k8s::install::cni_plugins (
  K8s::Ensure $ensure               = $k8s::ensure,
  String[1] $version                = 'v1.6.2',
  String[1] $method                 = $k8s::native_packaging,
  String[1] $download_url_template  = 'https://github.com/containernetworking/plugins/releases/download/%{version}/cni-plugins-linux-%{arch}-%{version}.tgz',
  Optional[String[1]] $package_name = undef,
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
      $_target = "/opt/k8s/cni-${version}";
      $_tarball_target = '/opt/k8s/archives';

      file { $_target:
        ensure  => stdlib::ensure($ensure, 'directory'),
      }
      if $ensure == present {
        # Store the cni plugin version in a static fact, to retain the plugin directory for copying from on upgrades
        file { '/etc/facter/facts.d/cni_plugins_version.txt':
          ensure  => file,
          content => "cni_plugins_version=${version}",
          require => File['/opt/cni/bin'],
        }
        if fact('cni_plugins_version') and fact('cni_plugins_version') != $version {
          $_old_target = "/opt/k8s/cni-${fact('cni_plugins_version')}"
          file { $_old_target:
            ensure => directory,
          }

          exec { 'Retain custom CNI binaries':
            command     => "cp --no-clobber '${_old_target}'/* '${_target}'",
            path        => fact('path'),
            refreshonly => true,
            subscribe   => File['/opt/cni/bin'],
          }
        }
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
    'package': {
      if $k8s::manage_repo or $package_name == 'kubernetes-cni' {
        $_package_name = pick($package_name, 'kubernetes-cni')
      } else {
        if fact('os.family') == 'suse' {
          $_package_name = pick($package_name, 'cni-plugins')
        } else {
          $_package_name = pick($package_name, 'containernetworking-plugins')
        }

        if fact('os.family') == 'RedHat' {
          $_target = '/usr/libexec/cni'
        } else {
          $_target = '/usr/lib/cni'
        }

        file { '/opt/cni/bin':
          ensure  => link,
          target  => $_target,
          require => Package[$_package_name],
        }
      }
      ensure_packages([$_package_name,])

      if $k8s::manage_repo {
        Class['k8s::repo'] -> Package[$_package_name]
      }
    }
    default: {
      fail("install method ${method} not supported")
    }
  }
}
