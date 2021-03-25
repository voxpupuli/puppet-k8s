class k8s::server::scheduler(
  Enum['present', 'absent'] $ensure = $k8s::ensure,

  Stdlib::HTTPUrl $master = $k8s::node::master,

  Hash[String, Data] $arguments = {},

  Stdlib::Unixpath $cert_path = $k8s::server::tls::cert_path,
  Stdlib::Unixpath $ca_cert = $k8s::server::tls::ca_cert,
  Stdlib::Unixpath $cert = "${cert_path}/kube-scheduler.pem",
  Stdlib::Unixpath $key = "${cert_path}/kube-scheduler.key",
) {
  k8s::binary { 'kube-scheduler':
    ensure => $ensure,
  }

  $kubeconfig = '/srv/kubernetes/kube-scheduler.kubeconf'
  kubeconfig { $kubeconfig:
    ensure      => $ensure,
    server      => $master,

    ca_cert     => $ca_cert,
    client_cert => $cert,
    client_key  => $key,
  }

  $args = k8s::format_arguments({
      kubeconfig   => $kubeconfig,
      leader_elect => true,
  } + $arguments)
}
