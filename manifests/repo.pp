# @summary Handles repositories for the container runtime
#
# @param container_manager The name of the container manager
# @param crio_version version o cri-o
# @param manage_container_manager whether to add cri-o repository or not
#
class k8s::repo (
  Boolean $manage_container_manager          = $k8s::manage_container_manager,
  K8s::Container_runtimes $container_manager = $k8s::container_manager,
  String[1] $crio_version                    = $k8s::version.split('\.')[0, 2].join('.'),
  Boolean $use_kubic_repos                   = false
) {
  case fact('os.family') {
    'Debian': {
      case fact('os.name') {
        'Debian': {
          $release_name = "Debian_${fact('os.release.major')}"
        }
        'Ubuntu': {
          $release_name = "xUbuntu_${fact('os.release.full')}"
        }
        'Raspbian': {
          $release_name = "Raspbian_${fact('os.release.full')}"
        }
        default: {}
      }

      if $use_kubic_repos {
        $kubernames_name = 'libcontainers:stable'
        $kubernames_repo = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${release_name}"
        $kubernetes_key  = '2472D6D0D2F66AF87ABA8DA34D64390375060AA4',
        $crio_name       = 'libcontainers:stable:cri-o'
        $crio_url        = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${crio_version}/${release_name}"
        $crio_key        = '2472D6D0D2F66AF87ABA8DA34D64390375060AA4',
      } else {
        $kubernetes_name = 'kubernetes'
        $kubernetes_repo = "https://pkgs.k8s.io/core:/stable:/v${crio_version}/deb"
        $kubernetes_key  = 'kubernetes-apt-keyring.gpg'
        $crio_name       = 'cri-o'
        $crio_url        = "https://pkgs.k8s.io/addons:/cri-o:/stable:/v${crio_version}/deb"
        $crio_key        = 'cri-o-apt-keyring.gpg'
      }

      apt::source { $kubernames_name:
        location => $kubernetes_repo,
        repos    => '/',
        release  => '',
        key      => {
          name   => $kubernetes_key,
          source => "${kubernetes_repo}/Release.key",
        },
      }

      if $manage_container_manager and $container_manager == 'crio' {
        apt::source { $crio_name:
          location => $crio_url,
          repos    => '/',
          release  => '',
          key      => {
            name   => $crio_key,
            source => "${crio_url}/Release.key",
          },
        }
      }
    }
    'RedHat': {
      $release_name = if versioncmp(fact('os.release.major'), '7') == 1 { "CentOS_${fact('os.release.major')}_Stream" } else { "CentOS_${fact('os.release.major')}" }
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
