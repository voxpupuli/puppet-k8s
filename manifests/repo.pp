# @summary Handles repositories for the container runtime
#
# @param manage_container_manager Whether to add the CRI-o repository or not
# @param container_manager The name of the container manager
# @param major_version The major version of Kubernetes to deploy repos for
#
class k8s::repo (
  Boolean $manage_container_manager          = $k8s::manage_container_manager,
  K8s::Container_runtimes $container_manager = $k8s::container_manager,
  String[1] $major_version                   = $k8s::version.split('\.')[0, 2].join('.'),
) {
  case fact('os.family') {
    'Debian': {
      $core_url = "https://pkgs.k8s.io/core:/stable:/v${major_version}/deb"
      $crio_url = "https://pkgs.k8s.io/addons:/cri-o:/stable:/v${major_version}/deb"

      apt::source { 'libcontainers:stable':
        ensure => absent,
      }
      apt::source { 'k8s-core':
        location => $core_url,
        repos    => '/',
        release  => '',
        key      => {
          name   => 'k8s-core-apt-keyring.asc',
          source => "${core_url}/Release.key",
        },
      }

      if $manage_container_manager and $container_manager == 'crio' {
        apt::source { 'libcontainers:stable:cri-o':
          ensure => absent,
        }
        apt::source { 'k8s-crio':
          location => $crio_url,
          repos    => '/',
          release  => '',
          key      => {
            name   => 'k8s-crio-apt-keyring.asc',
            source => "${crio_url}/Release.key",
          },
        }
        ~> exec { 'Fix conmon upgrade collision':
          command     => 'dpkg --no-triggers --force depends -r conmon',
          onlyif      => 'dpkg -S /usr/libexec/crio/conmon | grep "conmon:"',
          refreshonly => true,
          path        => fact('path'),
        }
      }
    }
    'RedHat': {
      $core_url = "https://pkgs.k8s.io/core:/stable:/v${major_version}/rpm"
      $crio_url = "https://pkgs.k8s.io/addons:/cri-o:/stable:/v${major_version}/rpm"

      yumrepo { 'libcontainers:stable':
        ensure => absent,
      }
      yumrepo { 'k8s-core':
        descr    => 'Stable releases of Kubernetes',
        baseurl  => $core_url,
        gpgcheck => 1,
        gpgkey   => "${core_url}repodata/repomd.xml.key",
      }

      if $manage_container_manager {
        case $container_manager {
          'crio': {
            yumrepo { 'libcontainers:stable:cri-o':
              ensure => absent,
            }
            yumrepo { 'k8s-crio':
              descr    => 'Stable releases of CRI-o',
              baseurl  => $crio_url,
              gpgcheck => 1,
              gpgkey   => "${crio_url}repodata/repomd.xml.key",
            }
          }
          'containerd': {
            yumrepo { 'docker-ce-stable':
              descr    => 'Docker CE Stable - $basearch',
              baseurl  => 'https://download.docker.com/linux/centos/$releasever/$basearch/stable',
              gpgcheck => 1,
              gpgkey   => 'https://download.docker.com/linux/centos/gpg',
            }
          }
          default: {}
        }
      }
    }
    default: {}
  }
}
