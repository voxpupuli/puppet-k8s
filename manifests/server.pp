class k8s::server(
  Enum['present', 'absent'] $ensure = $k8s::ensure,
  Integer[1] $api_port = 6443,

  Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR] $cluster_cidr = $k8s::cluster_cidr,
  Stdlib::IP::Address::Nosubnet $dns_service_address = $k8s::dns_service_address,
  String $cluster_domain = $k8s::cluster_domain,
  String $direct_master = "https://${fact('networking.ip')}:${api_port}",

  Stdlib::Unixpath $cert_path = '/etc/kubernetes/certs',
  Stdlib::Unixpath $ca_key = "${cert_path}/ca.key",
  Stdlib::Unixpath $ca_cert = "${cert_path}/ca.pem",
  Stdlib::Unixpath $aggregator_ca_key = "${cert_path}/aggregator-ca.key",
  Stdlib::Unixpath $aggregator_ca_cert = "${cert_path}/aggregator-ca.pem",

  Boolean $manage_etcd = $k8s::manage_etcd,
  Boolean $manage_certs = true,
  Boolean $manage_signing = false,
  Boolean $manage_components = true,
  Boolean $manage_resources = true,
  Boolean $node_on_server = true,
) {
  if $manage_etcd {
    include k8s::server::etcd
  }
  if $manage_certs {
    include k8s::server::tls
  }
  if $manage_components {
    include k8s::server::apiserver

    # XXX Think of a better way to do this
    if $k8s::master == 'https://kubernetes:6443' {
      class { 'k8s::server::controller_manager':
        master => 'https://localhost:6443',
      }
      class { 'k8s::server::scheduler':
        master => 'https://localhost:6443',
      }
    } else {
      include k8s::server::controller_manager
      include k8s::server::scheduler
    }
  }
  if $manage_resources {
    include k8s::server::resources
  }

  if $ensure == 'present' and $manage_signing {
    # Needs the PuppetDB terminus installed
    $pql_query = @("PQL")
    resources[certname] {
      type = 'Class' and
      title = 'K8s::Node::Kubelet'
      order by certname
    }
    | - PQL

    $cluster_nodes = puppetdb_query($pql_query)
    $cluster_nodes.each |$node| {
      k8s::server::tls::k8s_sign { $node['certname']:
      }
    }
  }

  include k8s::node::kubectl
  kubeconfig { '/root/.kube/config':
    ensure      => $ensure,
    server      => "https://localhost:${api_port}",
    require     => File['/root/.kube'],

    ca_cert     => $ca_cert,
    client_cert => "${cert_path}/admin.pem",
    client_key  => "${cert_path}/admin.key",
  }

  if $node_on_server {
    $_dir = $k8s::server::tls::cert_path

    class { 'k8s::node':
      ensure     => $ensure,
      master     => "https://localhost:${api_port}",
      node_auth  => 'cert',
      proxy_auth => 'cert',
      ca_cert    => $ca_cert,
      node_cert  => "${_dir}/node.pem",
      node_key   => "${_dir}/node.key",
      proxy_cert => "${_dir}/kube-proxy.pem",
      proxy_key  => "${_dir}/kube-proxy.key",
    }
  }
}
