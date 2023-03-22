# Class: k8s::install::container_runtime
#
# @summary manages the installation of cri
#
# @param manage_repo whether to manage the repo or not
# @param container_manager set the cri to use
# @param crio_package cri-o the package name
# @param containerd_package the containerd package anme
# @param k8s_version the k8s version
# @param runc_version the runc version
#
class k8s::install::container_runtime (
  Boolean $manage_repo                       = $k8s::manage_repo,
  K8s::Container_runtimes $container_manager = $k8s::container_manager,
  Optional[String[1]] $crio_package          = $k8s::crio_package,
  Optional[String[1]] $containerd_package    = $k8s::containerd_package,
  String[1] $k8s_version                     = $k8s::version,
  String[1] $runc_version                    = $k8s::runc_version,
) {
  case $container_manager {
    'crio': {
      if fact('os.family') == 'Debian' {
        $_crio_version = $k8s_version.split('\.')[0, 2].join('.')
        if versioncmp($_crio_version, '1.17') < 0 {
          $pkg = pick($crio_package, "cri-o-${_crio_version}")
        } else {
          $pkg = pick($crio_package, 'cri-o')
        }

        # This is needed by cri-o, but it is not a dependency of the package
        package { 'runc':
          ensure => $runc_version,
        }

        # Avoid a potential issue with some CRI-o versions
        file { ['/usr/lib/cri-o-runc/sbin', '/usr/lib/cri-o-runc']:
          ensure => directory,
        }

        file { '/usr/lib/cri-o-runc/sbin/runc':
          ensure  => link,
          target  => '/usr/sbin/runc',
          replace => false,
        }
      } else {
        $pkg = pick($crio_package, 'cri-o')
      }

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

      file_line { 'K8s crio cgroup manager':
        path    => '/etc/crio/crio.conf',
        line    => 'cgroup_manager = "systemd"',
        match   => '^cgroup_manager',
        require => Package['k8s container manager'],
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
    name => $pkg,
  }

  if $manage_repo {
    Class['k8s::repo'] -> Package['k8s container manager']
  }
}
