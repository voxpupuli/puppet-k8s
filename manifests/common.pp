# @summary Sets up common Kubernetes components - users/groups/folders/etc
class k8s::common {
  group { $k8s::group:
    ensure => present,
    system => true,
    gid    => $k8s::gid,
  }

  user { $k8s::user:
    ensure     => present,
    comment    => 'Kubernetes user',
    gid        => $k8s::group,
    home       => '/srv/kubernetes',
    managehome => false,
    shell      => (fact('os.family') ? {
        'Debian' => '/usr/sbin/nologin',
        default  => '/sbin/nologin',
    }),
    system     => true,
    uid        => $k8s::uid,
  }

  file {
    default:
      ensure  => directory,
      force   => true,
      purge   => true,
      recurse => true;

    '/opt/k8s': ;
    '/opt/k8s/bin': ;
  }

  file { '/var/run/kubernetes':
    ensure => directory,
    owner  => $k8s::user,
    group  => $k8s::group,
  }

  file { "${k8s::sysconfig_path}/kube-common":
    ensure  => file,
    content => epp('k8s/sysconfig.epp', {
        comment               => 'General Kubernetes Configuration',
        environment_variables => {
          'KUBE_LOG_LEVEL'   => '',
        },
    }),
  }

  file {
    default:
      ensure => directory;

    '/etc/kubernetes': ;
    '/etc/kubernetes/certs': ;
    '/etc/kubernetes/manifests':
      purge   => $k8s::purge_manifests,
      recurse => true;
    '/root/.kube': ;
    '/srv/kubernetes':
      owner => $k8s::user,
      group => $k8s::group;
    '/usr/libexec/kubernetes': ;
    '/var/lib/kubelet': ;
    '/var/lib/kubelet/pki': ;

    '/usr/share/containers/': ;
    '/usr/share/containers/oci/': ;
    '/usr/share/containers/oci/hooks.d': ;
  }
}
