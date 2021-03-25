class k8s::server::controller_manager(
  Enum['present', 'absent'] $ensure = $k8s::ensure,

  Stdlib::HTTPUrl $master = $k8s::node::master,

  Hash[String, Data] $arguments = {},

  Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR] $service_cluster_cidr = $k8s::service_cluster_cidr,
  Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR] $cluster_cidr = $k8s::cluster_cidr,

  Stdlib::Unixpath $cert_path = $k8s::server::tls::cert_path,
  Stdlib::Unixpath $ca_cert = $k8s::server::tls::ca_cert,
  Stdlib::Unixpath $ca_key = $k8s::server::tls::ca_key,
  Stdlib::Unixpath $cert = "${cert_path}/kube-controller-manager.pem",
  Stdlib::Unixpath $key = "${cert_path}/kube-controller-manager.key",
) {
  k8s::binary { 'kube-controller-manager':
    ensure => $ensure,
  }

  $kubeconfig = '/srv/kubernetes/kube-controller-manager.kubeconf'
  kubeconfig { $kubeconfig:
    ensure      => $ensure,
    server      => $master,

    ca_cert     => $ca_cert,
    client_cert => $cert,
    client_key  => $key,
  }

  # For container;
  # use_service_account_credentials => true,
  $args = k8s::format_arguments({
      kubeconfig                       => $kubeconfig,
      allocate_node_cidr               => true,
      cluster_cidr                     => $cluster_cidr,
      service_cluster_ip_range         => $service_cluster_cidr,
      cluster_signing_cert_file        => $ca_cert,
      cluster_signing_key_file         => $ca_key,
      leader_elect                     => true,
      root_ca_file                     => $ca_cert,
      service_account_private_key_file => "${cert_path}/service-account.key",
  } + $arguments)
}
