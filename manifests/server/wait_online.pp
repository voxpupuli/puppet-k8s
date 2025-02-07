# @summary Creates a dummy exec to allow deferring applies until the Kubernetes API server has started
#
# @param tries Number of retries
# @param try_sleep Sleep time in seconds
# @param timeout Execution timeout in seconds (0 to disable)
class k8s::server::wait_online (
  Integer $tries = 2,
  Integer $timeout = 5,
  Integer $try_sleep = 2,
) {
  # Wait up to 30 seconds for kube-apiserver to start
  exec { 'k8s apiserver wait online':
    command     => 'kubectl --kubeconfig /root/.kube/config version',
    path        => $facts['path'],
    refreshonly => true,
    tries       => $tries,
    try_sleep   => $try_sleep,
    timeout     => $timeout,
  }

  # Require possibly managed components before checking online state
  Kubeconfig <| title == '/root/.kube/config' |> -> Exec['k8s apiserver wait online']
  K8s::Binary <| title == 'kubectl' |> -> Exec['k8s apiserver wait online']
  Service <| title == 'kube-apiserver' |> ~> Exec['k8s apiserver wait online']
}
