class k8s::server(
  Integer[1] $api_port = 6443,

  Boolean $manage_etcd = $k8s::manage_etcd,
  Boolean $manage_certs = true,
  Boolean $node_on_server = true,
) {
  if $manage_etcd {
    include k8s::server::etcd
  }
  include k8s::server::tls
  include k8s::server::apiserver
  include k8s::server::controller_manager
  include k8s::server::scheduler

  include k8s::node::kubectl
  $_dir = $k8s::server::tls::cert_dir
  kubeconfig { '/root/.kube/config':
    server      => "https://localhost:${api_port}",

    ca_cert     => $k8s::server::tls::ca_cert,
    client_cert => "${_dir}/admin.pem",
    client_key  => "${_dir}/admin.key",

    require     => K8s::Binary['kubectl'],
  }

  k8s::server::bootstrap_token { fqdn_rand_string(6):
    kubeconfig         => '/root/.kube/config',

    description        => 'Puppet generated token',
    use_authentication => true,

    addn_data          => {
      metadata => {
        labels => {
          'puppet.com/managed' => 'true',
        },
      },
    },
    require            => K8s::Binary['kubectl'],
  }

  if $node_on_server {
    $_dir = $k8s::server::tls::cert_path

    class { 'k8s::node':
      master     => "https://localhost:${api_port}",
      node_auth  => 'cert',
      ca_cert    => $k8s::server::tls::ca_cert,
      node_cert  => "${_dir}/node.pem",
      node_key   => "${_dir}/node.key",
      proxy_cert => "${_dir}/kube-proxy.pem",
      proxy_key  => "${_dir}/kube-proxy.key",
    }
  }
}
