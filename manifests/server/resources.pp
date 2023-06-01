# @summary Generates and deploys standard Kubernetes in-cluster services
class k8s::server::resources (
  Stdlib::Unixpath $kubeconfig = '/root/.kube/config',

  K8s::CIDR $cluster_cidr                = $k8s::server::cluster_cidr,
  K8s::IP_addresses $dns_service_address = $k8s::server::dns_service_address,
  Stdlib::Unixpath $ca_cert              = $k8s::server::tls::ca_cert,
  String[1] $cluster_domain              = $k8s::server::cluster_domain,
  String[1] $master                      = $k8s::server::master,

  Boolean $manage_bootstrap            = true,
  Boolean $manage_coredns              = true,
  Boolean $manage_flannel              = true,
  K8s::Proxy_method $manage_kube_proxy = $k8s::manage_kube_proxy,

  String[1] $kube_proxy_image                    = "${k8s::container_registry}/kube-proxy",
  String[1] $kube_proxy_tag                      = "v${k8s::version}",
  Hash[String,Data] $kube_proxy_daemonset_config = {},
  Hash[String,Data] $extra_kube_proxy_args       = {},
  String[1] $coredns_image                       = 'coredns/coredns',
  String[1] $coredns_tag                         = '1.8.7',
  Hash[String,Data] $coredns_deployment_config   = {},
  String[1] $flannel_cni_image                   = 'rancher/mirrored-flannelcni-flannel-cni-plugin',
  String[1] $flannel_cni_tag                     = 'v1.0.0',
  String[1] $flannel_image                       = 'rancher/mirrored-flannelcni-flannel',
  String[1] $flannel_tag                         = 'v0.16.1',
  Hash[String,Data] $flannel_daemonset_config    = {},
) {
  assert_private()

  if $manage_bootstrap {
    include k8s::server::resources::bootstrap
  }

  if $manage_kube_proxy and $manage_kube_proxy != 'on-node' {
    include k8s::server::resources::kube_proxy
  }

  if $manage_coredns {
    include k8s::server::resources::coredns
  }

  if $manage_flannel {
    include k8s::server::resources::flannel
  }

  # Cluster role bindings
  kubectl_apply {
    default:
      kubeconfig  => $kubeconfig,
      provider    => 'kubectl',
      api_version => 'rbac.authorization.k8s.io/v1',
      kind        => 'ClusterRoleBinding',
      update      => false;

    # 'system:default SA RoleBinding':
    #   name => 'system:default-sa',
    #   data => {
    #     subjects => [
    #       {
    #         kind      => 'ServiceAccount',
    #         name      => 'default',
    #         namespace => 'kube-system',
    #       },
    #     ],
    #     roleRef  => {
    #       kind     => 'ClusterRole',
    #       name     => 'cluster-admin',
    #       apiGroup => 'rbac.authorization.k8s.io',
    #     }
    #   };

    'controller-manager RoleBinding':
      resource_name => 'controller-manager',
      content       => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        subjects => [
          {
            kind      => 'ServiceAccount',
            name      => 'kube-controller-manager',
            namespace => 'kube-system',
          },
          {
            apiGroup => 'rbac.authorization.k8s.io',
            kind     => 'User',
            name     => 'system:kube-controller-manager',
          },
        ],
        roleRef  => {
          kind     => 'ClusterRole',
          name     => 'cluster-admin', # 'system:kube-controller-manager'
          apiGroup => 'rbac.authorization.k8s.io',
        },
      };

    'kube-proxy RoleBinding':
      resource_name => 'kube-proxy',
      content       => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        subjects => [
          {
            kind      => 'ServiceAccount',
            name      => 'kube-proxy',
            namespace => 'kube-system',
          },
        ],
        roleRef  => {
          kind     => 'ClusterRole',
          name     => 'system:node-proxier',
          apiGroup => 'rbac.authorization.k8s.io',
        },
      };
  }
  # Service accounts
  kubectl_apply {
    default:
      kubeconfig  => $kubeconfig,
      provider    => 'kubectl',
      api_version => 'v1',
      namespace   => 'kube-system',
      kind        => 'ServiceAccount',
      content     => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
      };

    'kube-controller-manager SA':
      resource_name => 'kube-controller-manager';

    'kube-proxy SA':
      resource_name => 'kube-proxy';
  }
  # Config maps
  kubectl_apply {
    default:
      kubeconfig  => $kubeconfig,
      provider    => 'kubectl',
      api_version => 'v1',
      kind        => 'ConfigMap',
      namespace   => 'kube-system';

    # Default kubeconfig for using the local serviceaccount against an external apiserver URL
    # This is useful for e.g. kube-proxy - and proxy-replacing network fabrics - where the internal URL (https://kubernetes.default) might not be available
    'kubeconfig-in-cluster':
      content => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        data     => {
          kubeconfig => to_yaml({
              apiVersion        => 'v1',
              kind              => 'Config',
              'current-context' => 'local',
              clusters          => [
                {
                  name    => 'local',
                  cluster => {
                    server                  => $master,
                    'certificate-authority' => '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
                  },
                },
              ],
              users             => [
                {
                  name => 'local',
                  user => {
                    tokenFile => '/var/run/secrets/kubernetes.io/serviceaccount/token',
                  },
                },
              ],
              contexts          => [
                {
                  name    => 'local',
                  context => {
                    cluster => 'local',
                    user    => 'local',
                  },
                },
              ],
          }),
        },
      };
  }
}
