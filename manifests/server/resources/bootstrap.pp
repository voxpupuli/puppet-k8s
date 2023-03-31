# @summary Generates and deploys the default Puppet boostrap configuration into the cluster
#
# @param master The main API URL to encode in the bootstrap configuration
class k8s::server::resources::bootstrap (
  K8s::Ensure $ensure                    = $k8s::ensure,
  Stdlib::Unixpath $kubeconfig           = $k8s::server::resources::kubeconfig,
  String[1] $master                      = $k8s::server::resources::master,
) {
  assert_private()

  k8s::server::bootstrap_token { 'puppet':
    ensure             => $ensure,
    kubeconfig         => $kubeconfig,

    description        => 'Puppet generated token',
    use_authentication => true,

    addn_data          => {
      metadata => {
        labels => {
          'kubernetes.io/managed-by' => 'puppet',
        },
      },
    },
  }

  if $facts['k8s_ca'] {
    kubectl_apply { 'cluster-info':
      ensure      => $ensure,
      kubeconfig  => $kubeconfig,
      provider    => 'kubectl',
      api_version => 'v1',
      kind        => 'ConfigMap',
      namespace   => 'kube-system',
      content     => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        data     => {
          ca         => String(Binary.new($facts['k8s_ca']), '%s'),
          kubeconfig => to_yaml({
              apiVersion        => 'v1',
              kind              => 'Config',
              clusters          => [
                {
                  name    => 'default',
                  cluster => {
                    server                       => $master,
                    'certificate-authority-data' => $facts['k8s_ca'],
                  },
                },
              ],
              users             => [],
              contexts          => [],
              preferences       => {},
              'current-context' => '',
          }),
        },
      },
    }
  }

  kubectl_apply {
    default:
      ensure      => $ensure,
      kubeconfig  => $kubeconfig,
      provider    => 'kubectl',
      api_version => 'rbac.authorization.k8s.io/v1',
      kind        => 'ClusterRole',
      update      => false;

    'puppet:cluster-info:reader Role':
      kind          => 'Role',
      namespace     => 'kube-system',
      resource_name => 'puppet:cluster-info:reader',
      content       => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        rules    => [
          {
            apiGroups     => [''],
            resources     => [
              'configmaps',
            ],
            resourceNames => [
              'cluster-info',
            ],
            verbs         => [
              'get',
            ],
          },
        ],
      };

    'system:certificates.k8s.io:certificatesigningrequests:nodeclient':
      content => {
        metadata => {
          annotations => {
            'rbac.authorization.kubernetes.io/autoupdate' => 'true',
          },
          labels      => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        rules    => [
          {
            apiGroups => [
              'certificates.k8s.io',
            ],
            resources => [
              'certificatesigningrequests/nodeclient',
            ],
            verbs     => [
              'create',
            ],
          },
        ],
      };

    'system:certificates.k8s.io:certificatesigningrequests:selfnodeclient':
      content => {
        metadata => {
          annotations => {
            'rbac.authorization.kubernetes.io/autoupdate' => 'true',
          },
          labels      => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        rules    => [
          {
            apiGroups => [
              'certificates.k8s.io',
            ],
            resources => [
              'certificatesigningrequests/selfnodeclient',
            ],
            verbs     => [
              'create',
            ],
          },
        ],
      };

    'system:certificates.k8s.io:certificatesigningrequests:selfnodeserver':
      content => {
        metadata => {
          annotations => {
            'rbac.authorization.kubernetes.io/autoupdate' => 'true',
          },
          labels      => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        rules    => [
          {
            apiGroups => [
              'certificates.k8s.io',
            ],
            resources => [
              'certificatesigningrequests/selfnodeserver',
            ],
            verbs     => [
              'create',
            ],
          },
        ],
      };
  }

  kubectl_apply {
    default:
      ensure      => $ensure,
      kubeconfig  => $kubeconfig,
      provider    => 'kubectl',
      api_version => 'rbac.authorization.k8s.io/v1',
      kind        => 'ClusterRoleBinding';

    'puppet:cluster-info:reader RoleBinding':
      kind          => 'RoleBinding',
      namespace     => 'kube-system',
      resource_name => 'puppet:cluster-info:reader',
      content       => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        roleRef  => {
          apiGroup => 'rbac.authorization.k8s.io',
          kind     => 'Role',
          name     => 'puppet:cluster-info:reader',
        },
        subjects => [
          {
            apiGroup => 'rbac.authorization.k8s.io',
            kind     => 'Group',
            name     => 'system:authenticated',
          },
          {
            apiGroup => 'rbac.authorization.k8s.io',
            kind     => 'Group',
            name     => 'system:unauthenticated',
          },
        ],
      };

    'system-bootstrap-node-bootstrapper':
      content => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        subjects => [
          {
            kind     => 'Group',
            name     => 'system:bootstrappers',
            apiGroup => 'rbac.authorization.k8s.io',
          },
          {
            kind     => 'Group',
            name     => 'system:nodes',
            apiGroup => 'rbac.authorization.k8s.io',
          },
        ],
        roleRef  => {
          kind     => 'ClusterRole',
          name     => 'system:node-bootstrapper',
          apiGroup => 'rbac.authorization.k8s.io',
        },
      };

    'system-bootstrap-approve-node-client-csr':
      content => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        subjects => [
          {
            kind     => 'Group',
            name     => 'system:bootstrappers',
            apiGroup => 'rbac.authorization.k8s.io',
          },
        ],
        roleRef  => {
          kind     => 'ClusterRole',
          name     => 'system:certificates.k8s.io:certificatesigningrequests:nodeclient',
          apiGroup => 'rbac.authorization.k8s.io',
        },
      };

    'system-bootstrap-node-renewal':
      content => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        subjects => [
          {
            kind     => 'Group',
            name     => 'system:nodes',
            apiGroup => 'rbac.authorization.k8s.io',
          },
        ],
        roleRef  => {
          kind     => 'ClusterRole',
          name     => 'system:certificates.k8s.io:certificatesigningrequests:selfnodeclient',
          apiGroup => 'rbac.authorization.k8s.io',
        },
      };

    'system-bootstrap-node-server-renewal':
      content => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        subjects => [
          {
            kind     => 'Group',
            name     => 'system:nodes',
            apiGroup => 'rbac.authorization.k8s.io',
          },
        ],
        roleRef  => {
          kind     => 'ClusterRole',
          name     => 'system:certificates.k8s.io:certificatesigningrequests:selfnodeserver',
          apiGroup => 'rbac.authorization.k8s.io',
        },
      };
  }
}
