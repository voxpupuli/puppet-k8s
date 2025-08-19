# @summary Sets up a Kubernetes server instance
#
# @param admin_cert path to the admin cert
# @param admin_key path to the admin key
# @param aggregator_ca_cert path to the aggregator ca cert
# @param aggregator_ca_key path to the aggregator ca key
# @param api_port Cluster API port
# @param ca_cert path to the ca cert
# @param ca_key path to the ca key
# @param cert_path path to cert files
# @param cluster_cidr cluster cidr
# @param cluster_domain cluster domain name
# @param control_plane_url cluster API connection
# @param direct_control_plane_url direct clust API connection
# @param dns_service_address cluster dns service address
# @param ensure set ensure for installation or deinstallation
# @param etcd_cluster_name name of the etcd cluster for searching its nodes in the puppetdb
# @param etcd_servers list etcd servers if no puppetdb is used
# @param firewall_type define the type of firewall to use
# @param generate_ca initially generate ca
# @param manage_certs whether to manage certs or not
# @param manage_components whether to manage components or not
# @param manage_crictl whether to install crictl or not
# @param manage_etcd whether to manage etcd or not
# @param manage_firewall whether to manage firewall or not
# @param manage_kubeadm whether to install kubeadm or not
# @param manage_resources whether to manage cluster internal resources or not
# @param manage_signing whether to manage cert signing or not
# @param node_on_server whether to use controller also as nodes or not
# @param puppetdb_discovery_tag enable puppetdb resource searching
#
class k8s::server (
  K8s::Ensure $ensure  = $k8s::ensure,
  Integer[1] $api_port = 6443,

  K8s::CIDR $cluster_cidr                = $k8s::cluster_cidr,
  K8s::IP_addresses $dns_service_address = $k8s::dns_service_address,
  String $cluster_domain                 = $k8s::cluster_domain,
  String $direct_control_plane_url       = "https://${fact('networking.ip')}:${api_port}",
  String $control_plane_url              = $k8s::control_plane_url,

  Stdlib::Unixpath $cert_path          = '/etc/kubernetes/certs',
  Stdlib::Unixpath $ca_key             = "${cert_path}/ca.key",
  Stdlib::Unixpath $ca_cert            = "${cert_path}/ca.pem",
  Stdlib::Unixpath $aggregator_ca_key  = "${cert_path}/aggregator-ca.key",
  Stdlib::Unixpath $aggregator_ca_cert = "${cert_path}/aggregator-ca.pem",
  Stdlib::Unixpath $admin_cert         = "${cert_path}/admin.pem",
  Stdlib::Unixpath $admin_key          = "${cert_path}/admin.key",

  Boolean $generate_ca              = false,
  Boolean $manage_etcd              = $k8s::manage_etcd,
  Boolean $manage_firewall          = $k8s::manage_firewall,
  Boolean $manage_certs             = true,
  Boolean $manage_signing           = $k8s::puppetdb_discovery,
  Boolean $manage_components        = true,
  Boolean $manage_resources         = true,
  Boolean $node_on_server           = true,
  Boolean $manage_kubeadm           = false,
  Boolean $manage_crictl            = false,
  String[1] $puppetdb_discovery_tag = $k8s::puppetdb_discovery_tag,

  Optional[Array[Stdlib::HTTPUrl]] $etcd_servers = undef,
  Optional[K8s::Firewall] $firewall_type         = $k8s::firewall_type,
  String[1] $etcd_cluster_name                   = $k8s::etcd_cluster_name,
) {
  include k8s::common

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
    include k8s::server::wait_online

    # XXX Think of a better way to do this
    if $control_plane_url == 'https://kubernetes:6443' {
      class { 'k8s::server::controller_manager':
        control_plane_url => 'https://localhost:6443',
      }
      class { 'k8s::server::scheduler':
        control_plane_url => 'https://localhost:6443',
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

  if $manage_kubeadm {
    include k8s::install::kubeadm
  }

  if $manage_crictl {
    include k8s::install::crictl
  }

  kubeconfig { '/root/.kube/config':
    ensure          => $ensure,
    server          => "https://localhost:${api_port}",
    require         => File['/root/.kube'],
    current_context => 'default',

    ca_cert         => $ca_cert,
    client_cert     => $admin_cert,
    client_key      => $admin_key,
  }

  if $node_on_server {
    if $manage_certs {
      $_dir = $k8s::server::tls::cert_path

      class { 'k8s::node':
        ensure            => $ensure,
        control_plane_url => "https://localhost:${api_port}",
        node_auth         => 'cert',
        proxy_auth        => 'cert',
        ca_cert           => $ca_cert,
        node_cert         => "${_dir}/node.pem",
        node_key          => "${_dir}/node.key",
        proxy_cert        => "${_dir}/kube-proxy.pem",
        proxy_key         => "${_dir}/kube-proxy.key",
      }
    } else {
      class { 'k8s::node':
        ensure => $ensure,
      }
    }
  }
}
