# @summary Signs pending CSR requests for bootstrapping clients
#
# TODO - This should probably be done as a service next to the apiservers
# @param kubeconfig Path to the kubeconfig file
#
define k8s::server::tls::k8s_sign (
  $kubeconfig = '/root/.kube/config',
) {
  $exec_command = [
    "kubectl --kubeconfig='${kubeconfig}' get csr",
    "grep 'system:node:${name}'",
    'grep Pending',
    "awk '{print \$1}'",
    "xargs -r kubectl --kubeconfig='${kubeconfig}' certificate approve",
  ].join(' | ')

  exec { "Sign ${name} cert":
    path    => $facts['path'],
    command => $exec_command,
    onlyif  => "kubectl --kubeconfig='${kubeconfig}' get csr | grep 'system:node:${name}' | grep Pending",
    require => 'File[/usr/bin/kubectl]',
  }
}
