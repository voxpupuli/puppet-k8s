# @summary Creates a dummy exec to allow deferring applies until the Kubernetes API server has started
class k8s::server::wait_online {
  # Wait up to 30 seconds for kube-apiserver to start
  exec { 'k8s apiserver wait online':
    command     => 'kubectl --kubeconfig /root/.kube/config version',
    path        => $facts['path'],
    refreshonly => true,
    tries       => 15,
    try_sleep   => 2,
  }

  # Require possibly managed components before checking online state
  Kubeconfig <| title == '/root/.kube/config' |> -> Exec['k8s apiserver wait online']
  K8s::Binary <| title == 'kubectl' |> -> Exec['k8s apiserver wait online']
  Service <| title == 'kube-apiserver' |> ~> Exec['k8s apiserver wait online']
}
