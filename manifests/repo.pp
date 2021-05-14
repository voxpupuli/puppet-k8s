class k8s::repo(
  Boolean $manage_container_manager = $k8s::manage_container_manager,
  String[1] $crio_version = $k8s::version.split('\.')[0, 2].join('.'),
) {
  case fact('os.family') {
    'Debian': {
      if fact('os.name') == 'Debian' {
        $repo_name = "Debian_${fact('os.release.major')}"
      } elsif fact('os.name') == 'Ubuntu' {
        $repo_name = "xUbuntu_${fact('os.release.full')}"
      } elsif fact('os.name') == 'Raspbian' {
        $repo_name = "Raspbian_${fact('os.release.full')}"
      }
      $libcontainers_url = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${repo_name}/"
      $crio_url = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${crio_version}/${repo_name}/"

      apt::source { 'libcontainers:stable':
        location => $libcontainers_url,
        repos    => '/',
        key      => {
          id     => '2472D6D0D2F66AF87ABA8DA34D64390375060AA4',
          server => 'hkps.pool.sks-keyservers.net',
        },
      }
      if $manage_container_manager {
        apt::source { 'libcontainers:stable:cri-o':
          location => $crio_url,
          repos    => '/',
          key      => {
            id     => '2472D6D0D2F66AF87ABA8DA34D64390375060AA4',
            server => 'hkps.pool.sks-keyservers.net',
          },
        }
      }
    }
    'RedHat': {
      $libcontainers_url = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_${fact('os.release.major')}/"
      $crio_url = "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${crio_version}/CentOS_${fact('os.release.major')}/"

      yumrepo { 'libcontainers:stable':
        descr    => 'Stable releases of libcontainers',
        baseurl  => $libcontainers_url,
        gpgcheck => 1,
        gpgkey   => "${libcontainers_url}repodata/repomd.xml.key"
      }
      if $manage_container_manager {
        yumrepo { 'libcontainers:stable:cri-o':
          descr    => 'Stable releases of CRI-o',
          baseurl  => $crio_url,
          gpgcheck => 1,
          gpgkey   => "${crio_url}repodata/repomd.xml.key"
        }
      }
    }
  }
}
