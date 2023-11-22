# @summary Handles repositories for the container runtime
#
# @param manage_container_manager whether to add cri-o repository or not
# @param crio_version version o cri-o
# @param container_manager The name of the container manager
#
class k8s::repo (
  Boolean $manage_container_manager          = $k8s::manage_container_manager,
  K8s::Container_runtimes $container_manager = $k8s::container_manager,
  String[1] $crio_version                    = $k8s::version.split('\.')[0, 2].join('.'),
) {
  case fact('os.family') {
    'Debian': {
      case fact('os.name') {
        'Debian': {
          if versioncmp($crio_version, '1.19') >= 0 {
            $release_name = "Debian_${fact('os.release.major')}"
          } else {
            $release_name = 'Debian_Testing'
          }
        }
        'Ubuntu': {
          $release_name = "xUbuntu_${fact('os.release.full')}"
        }
        'Raspbian': {
          $release_name = "Raspbian_${fact('os.release.full')}"
        }
        default: {}
      }

      $libcontainers_url = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${release_name}"
      $crio_url          = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${crio_version}/${release_name}"

      apt::source { 'libcontainers:stable':
        location => $libcontainers_url,
        repos    => '/',
        release  => '',
        key      => {
          id     => '2472D6D0D2F66AF87ABA8DA34D64390375060AA4',
          source => "${libcontainers_url}/Release.key",
        },
      }

      if $manage_container_manager and $container_manager == 'crio' {
        apt::source { 'libcontainers:stable:cri-o':
          location => $crio_url,
          repos    => '/',
          release  => '',
          key      => {
            id     => '2472D6D0D2F66AF87ABA8DA34D64390375060AA4',
            source => "${crio_url}/Release.key",
          },
        }
      }
    }
    'RedHat': {
      $release_name = if fact('os.release.major') > 7 { "CentOS_${fact('os.release.major')}_Stream" } else { "CentOS_${fact('os.release.major')}" }
      $libcontainers_url = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${release_name}/"
      $crio_url          = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${crio_version}/${release_name}/"

      yumrepo { 'libcontainers:stable':
        descr    => 'Stable releases of libcontainers',
        baseurl  => $libcontainers_url,
        gpgcheck => 1,
        gpgkey   => "${libcontainers_url}repodata/repomd.xml.key",
      }

      if $manage_container_manager {
        case $container_manager {
          'crio': {
            yumrepo { 'libcontainers:stable:cri-o':
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
