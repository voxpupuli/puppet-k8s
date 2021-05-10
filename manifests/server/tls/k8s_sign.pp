define k8s::server::tls::k8s_sign(
  $kubeconfig = '/root/.kube/config',
) {
  exec { "Sign ${name} cert":
    path    => ['/usr/local/bin','/usr/bin','/bin'],
    command => "kubectl --kubeconfig='${kubeconfig}' get csr | grep 'system:node:${name}' | grep Pending | awk '{print \$1}' | xargs -rn1 kubectl --kubeconfig='${kubeconfig}' certificate approve",
    onlyif  => "kubectl --kubeconfig='${kubeconfig}' get csr | grep 'system:node:${name}' | grep Pending",
  }
}
