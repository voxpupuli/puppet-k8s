# @summary Manages the installation of a container runtime / CRI
#
# @param manage_repo Whether to manage the repo or not
# @param container_manager The CRI implementation to install
# @param crio_package The CRI-o package name
# @param containerd_package The containerd package name
# @param runc_version The runc version
# @param package_ensure The ensure value to set on the cri package
#
class k8s::install::container_runtime (
  Boolean $manage_repo                       = $k8s::manage_repo,
  K8s::Container_runtimes $container_manager = $k8s::container_manager,
  Optional[String[1]] $crio_package          = $k8s::crio_package,
  Optional[String[1]] $containerd_package    = $k8s::containerd_package,
  String[1] $runc_version                    = $k8s::runc_version,
  String[1] $package_ensure                  = installed,
) {
  case $container_manager {
    'crio': {
      if fact('os.family') == 'Debian' {
        # This is required for cri-o, but it is not guaranteed to be a dependency of the package
        package { 'runc':
          ensure => $runc_version,
        }

        # Avoid a potential packaging issue
        file { ['/usr/lib/cri-o-runc/sbin', '/usr/lib/cri-o-runc']:
          ensure => directory,
        }

        file { '/usr/lib/cri-o-runc/sbin/runc':
          ensure  => link,
          target  => '/usr/sbin/runc',
          replace => false,
        }
      } elsif fact('os.family') == 'Suse' {
        file { '/usr/libexec/crio':
          ensure => directory,
        }
      }
      $pkg = pick($crio_package, 'cri-o')

      file { '/usr/libexec/crio/conmon':
        ensure  => link,
        target  => '/usr/bin/conmon',
        replace => false,
        require => Package['k8s container manager'],
      }

      file { '/etc/cni/net.d/100-crio-bridge.conf':
        ensure  => absent,
        require => Package['k8s container manager'],
      }

      file { ['/etc/crio', '/etc/crio/crio.conf.d']:
        ensure => directory;
      }
      file { 'K8s crio cgroup manager':
        path    => '/etc/crio/crio.conf.d/10-systemd.conf',
        content => "[crio.runtime]\ncgroup_manager = \"systemd\"",
        # TODO - Necessary/wanted to force it?
        # notify => Service[crio],
      }
    }
    'containerd': {
      file { '/etc/containerd':
        ensure => directory,
      }
      -> file { '/etc/containerd/config.toml':
        ensure => file,
        source => 'puppet:///modules/k8s/containerd/config.toml',
        notify => Service['containerd'],
      }
      -> service { 'containerd':
        ensure  => running,
        require => Package['k8s container manager'],
      }

      $pkg = pick($containerd_package, 'containerd')
    }
    default: {}
  }

  package { 'k8s container manager':
    ensure => $package_ensure,
    name   => $pkg,
  }

  file {
    default:
      ensure => directory;

    '/usr/share/containers/': ;
    '/usr/share/containers/oci/': ;
    '/usr/share/containers/oci/hooks.d': ;
  }

  if $manage_repo {
    require k8s::repo
  }
}
