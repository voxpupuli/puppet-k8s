define k8s::server::tls::k8s_sign(
  $kubeconfig = '/root/.kube/config',
) {
  exec { "Sign ${name} cert":
    path    => ['/usr/local/bin','/usr/bin','/bin'],
    command => "kubectl --kubeconfig='${kubeconfig}' certificate approve ${name}",
    unless  => "kubectl --kubeconfig='${kubeconfig}' get csr ${name} | grep Approved",
    onlyif  => "kubectl --kubeconfig='${kubeconfig}' get csr ${name}",
  }
}
