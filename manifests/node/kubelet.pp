class k8s::node::kubelet(
  Enum['present', 'absent'] $ensure = $k8s::ensure,

  Stdlib::HTTPUrl $master = $k8s::master,

  Optional[String[1]] $bootstrap_token = undef,
) {
  k8s::binary { 'kubelet':
    ensure    => $ensure,
  }

  if $bootstrap_token {
    kubeconfig { '/srv/kubernetes/bootstrap-kubelet.kubeconf':
      server => $master,
      token  => $bootstrap_token,
    }
  } else {
    kubeconfig { '/srv/kubernetes/kubelet.kubeconf':
      server => $master,
    }
  }

  file { '/etc/kubernetes/kubelet.conf':
    ensure  => $ensure,
    content => '',
  }
}
