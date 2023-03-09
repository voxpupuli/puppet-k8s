# @summary Sets up a Kubernetes server instance
#
# @param aggregator_ca_cert
# @param aggregator_ca_key
# @param api_port Cluster API port
# @param ca_cert path to the ca cert
# @param ca_key path to the ca key
# @param cert_path path to cert files
# @param cluster_cidr cluster cidr
# @param cluster_domain cluster domain name
# @param direct_master direct clust API connection
# @param dns_service_address cluster dns service address
# @param ensure
# @param etcd_servers list etcd servers if no puppetdb is used
# @param generate_ca initially generate ca
# @param manage_certs wether to manage certs or not
# @param manage_components wether to manage components or not
# @param manage_etcd wether to manage etcd or not
# @param manage_firewall wether to manage firewall or not
# @param manage_resources wether to manage cluster internal resources or not
# @param manage_signing wether to manage cert signing or not
# @param master cluster API connection
# @param node_on_server wether to use controller also as nodes or not
# @param puppetdb_discovery_tag enable puppetdb resource searching
#
class k8s::server (
  K8s::Ensure $ensure  = $k8s::ensure,
  Integer[1] $api_port = 6443,

  K8s::CIDR $cluster_cidr                = $k8s::cluster_cidr,
  K8s::IP_addresses $dns_service_address = $k8s::dns_service_address,
  String $cluster_domain                 = $k8s::cluster_domain,
  String $direct_master                  = "https://${fact('networking.ip')}:${api_port}",
  String $master                         = $k8s::master,

  Stdlib::Unixpath $cert_path          = '/etc/kubernetes/certs',
  Stdlib::Unixpath $ca_key             = "${cert_path}/ca.key",
  Stdlib::Unixpath $ca_cert            = "${cert_path}/ca.pem",
  Stdlib::Unixpath $aggregator_ca_key  = "${cert_path}/aggregator-ca.key",
  Stdlib::Unixpath $aggregator_ca_cert = "${cert_path}/aggregator-ca.pem",

  Boolean $generate_ca              = false,
  Boolean $manage_etcd              = $k8s::manage_etcd,
  Boolean $manage_firewall          = $k8s::manage_firewall,
  Boolean $manage_certs             = true,
  Boolean $manage_signing           = $k8s::puppetdb_discovery,
  Boolean $manage_components        = true,
  Boolean $manage_resources         = true,
  Boolean $node_on_server           = true,
  String[1] $puppetdb_discovery_tag = $k8s::puppetdb_discovery_tag,

  Optional[Array[Stdlib::HTTPUrl]] $etcd_servers = undef,
) {
  if $manage_etcd {
    class { 'k8s::server::etcd':
      ensure          => $ensure,
      generate_ca     => $generate_ca,
      manage_certs    => $manage_certs,
      manage_firewall => $manage_firewall,
      manage_members  => $k8s::puppetdb_discovery,
    }
  }
  if $manage_certs {
    include k8s::server::tls
  }
  if $manage_components {
    include k8s::server::apiserver

    # XXX Think of a better way to do this
    if $master == 'https://kubernetes:6443' {
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

    $pql_query = [
      'resources[certname] {',
      'type = \'Class\' and',
      'title = \'K8s::Node::Kubelet\' and',
      "parameters.puppetdb_discovery_tag = '${puppetdb_discovery_tag}'",
      'order by certname }',
    ].join(' ')

    $cluster_nodes = puppetdb_query($pql_query)
    $cluster_nodes.each |$node| { k8s::server::tls::k8s_sign { $node['certname']: } }
  }

  include k8s::install::kubectl
  include k8s::install::kubeadm

  kubeconfig { '/root/.kube/config':
    ensure          => $ensure,
    server          => "https://localhost:${api_port}",
    require         => File['/root/.kube'],
    current_context => 'default',

    ca_cert         => $ca_cert,
    client_cert     => "${cert_path}/admin.pem",
    client_key      => "${cert_path}/admin.key",
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
