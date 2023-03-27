# @summary Generates and deploys standard Kubernetes in-cluster services
class k8s::server::resources (
  Stdlib::Unixpath $kubeconfig = '/root/.kube/config',

  K8s::CIDR $cluster_cidr                = $k8s::server::cluster_cidr,
  K8s::IP_addresses $dns_service_address = $k8s::server::dns_service_address,
  Stdlib::Unixpath $ca_cert              = $k8s::server::tls::ca_cert,
  String[1] $cluster_domain              = $k8s::server::cluster_domain,
  String[1] $master                      = $k8s::server::master,

  Boolean $manage_bootstrap  = true,
  Boolean $manage_kube_proxy = $k8s::manage_kube_proxy,
  Boolean $manage_coredns    = true,
  Boolean $manage_flannel    = true,

  String[1] $kube_proxy_image                    = 'k8s.gcr.io/kube-proxy',
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
    k8s::server::bootstrap_token { 'puppet':
      kubeconfig         => $kubeconfig,

      description        => 'Puppet generated token',
      use_authentication => true,

      addn_data          => {
        metadata => {
          labels => {
            'puppet.com/managed' => 'true',
          },
        },
      },
    }

    if $facts['k8s_ca'] {
      kubectl_apply { 'cluster-info':
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

  if $manage_kube_proxy {
    include k8s::server::resources::kube_proxy
  }

  if $manage_coredns {
    include k8s::server::resources::coredns
  }

  if $manage_flannel {
    kubectl_apply {
      default:
        kubeconfig    => $kubeconfig,
        provider      => 'kubectl',
        namespace     => 'kube-system',
        resource_name => 'flannel';

      'flannel ClusterRole':
        api_version => 'rbac.authorization.k8s.io/v1',
        kind        => 'ClusterRole',
        content     => {
          metadata => {
            labels => {
              'kubernetes.io/managed-by' => 'puppet',
            },
          },
          rules    => [
            {
              apiGroups     => ['extensions'],
              resources     => ['podsecuritypolicies'],
              verbs         => ['use'],
              resourceNames => ['psp.flannel.unprivileged'],
            },
            {
              apiGroups => [''],
              resources => ['pods'],
              verbs     => ['get'],
            },
            {
              apiGroups => [''],
              resources => ['nodes'],
              verbs     => ['list','watch'],
            },
            {
              apiGroups => [''],
              resources => ['nodes/status'],
              verbs     => ['patch'],
            },
          ],
        };

      'flannel ClusterRoleBinding':
        api_version => 'rbac.authorization.k8s.io/v1',
        kind        => 'ClusterRoleBinding',
        content     => {
          metadata => {
            labels => {
              'kubernetes.io/managed-by' => 'puppet',
            },
          },
          subjects => [
            {
              kind      => 'ServiceAccount',
              name      => 'flannel',
              namespace => 'kube-system',
            },
          ],
          roleRef  => {
            kind     => 'ClusterRole',
            name     => 'flannel',
            apiGroup => 'rbac.authorization.k8s.io',
          },
        };

      'flannel ServiceAccount':
        api_version => 'v1',
        kind        => 'ServiceAccount',
        content     => {
          metadata => {
            labels => {
              'kubernetes.io/managed-by' => 'puppet',
            },
          },
        };

      'flannel ConfigMap':
        api_version => 'v1',
        kind        => 'ConfigMap',
        content     => {
          metadata => {
            labels => {
              tier                       => 'node',
              'k8s-app'                  => 'flannel',
              'kubernetes.io/managed-by' => 'puppet',
            },
          },
          data     => {
            'cni-conf.json' => to_json({
                name       => 'cbr0',
                cniVersion => '0.3.1',
                plugins    => [
                  {
                    type     => 'flannel',
                    delegate => {
                      hairpinMode      => true,
                      isDefaultGateway => true,
                    },
                  },
                  {
                    type         => 'portmap',
                    capabilities => {
                      portMappings => true,
                    },
                  },
                ],
            }),
            'net-conf.json' => to_json({
                'Network' => $cluster_cidr,
                'Backend' => {
                  'Type' => 'vxlan',
                },
            }),
          },
        };

      'flannel DaemonSet':
        api_version => 'apps/v1',
        kind        => 'DaemonSet',
        recreate    => true,
        content     => {
          metadata => {
            labels => {
              'tier'                     => 'node',
              'k8s-app'                  => 'flannel',
              'kubernetes.io/managed-by' => 'puppet',
            },
          },
          spec     => {
            selector       => {
              matchLabels => {
                'tier'                     => 'node',
                'k8s-app'                  => 'flannel',
                'kubernetes.io/managed-by' => 'puppet',
              },
            },
            template       => {
              metadata => {
                labels => {
                  'tier'                     => 'node',
                  'k8s-app'                  => 'flannel',
                  'kubernetes.io/managed-by' => 'puppet',
                },
              },
              spec     => {
                hostNetwork        => true,
                priorityClassName  => 'system-node-critical',
                serviceAccountName => 'flannel',
                tolerations        => [
                  {
                    effect   => 'NoSchedule',
                    operator => 'Exists',
                  },
                  {
                    effect   => 'NoExecute',
                    operator => 'Exists',
                  },
                ],
                nodeSelector       => {
                  'kubernetes.io/os' => 'linux',
                },
                containers         => [
                  {
                    name            => 'flannel',
                    image           => "${flannel_image}:${flannel_tag}",
                    command         => ['/opt/bin/flanneld'],
                    args            => ['--ip-masq', '--kube-subnet-mgr'],
                    resources       => {
                      requests => {
                        cpu    => '100m',
                        memory => '50Mi',
                      },
                      limits   => {
                        cpu    => '100m',
                        memory => '50Mi',
                      },
                    },
                    securityContext => {
                      privileged   => false,
                      capabilities => {
                        add => ['NET_ADMIN', 'NET_RAW'],
                      },
                    },
                    env             => [
                      {
                        name      => 'POD_NAME',
                        valueFrom => {
                          fieldRef => {
                            fieldPath => 'metadata.name',
                          },
                        },
                      },
                      {
                        name      => 'POD_NAMESPACE',
                        valueFrom => {
                          fieldRef => {
                            fieldPath => 'metadata.namespace',
                          },
                        },
                      },
                    ],
                    volumeMounts    => [
                      {
                        name      => 'run',
                        mountPath => '/run/flannel',
                      },
                      {
                        name      => 'flannel-cfg',
                        mountPath => '/etc/kube-flannel/',
                      },
                    ],
                  },
                ],
                initContainers     => [
                  {
                    name         => 'install-cni-plugin',
                    image        => "${flannel_cni_image}:${flannel_cni_tag}",
                    command      => ['cp'],
                    args         => [
                      '-f',
                      '/flannel',
                      '/opt/cni/bin/flannel',
                    ],
                    volumeMounts => [
                      {
                        name      => 'host-cni-bin',
                        mountPath => '/opt/cni/bin',
                      },
                    ],
                  },
                  {
                    name         => 'install-cni',
                    image        => "${flannel_image}:${flannel_tag}",
                    command      => ['cp'],
                    args         => [
                      '-f',
                      '/etc/kube-flannel/cni-conf.json',
                      '/etc/cni/net.d/10-flannel.conflist',
                    ],
                    volumeMounts => [
                      {
                        name      => 'cni',
                        mountPath => '/etc/cni/net.d',
                      },
                      {
                        name      => 'flannel-cfg',
                        mountPath => '/etc/kube-flannel',
                      },
                    ],
                  },
                ],
                volumes            => [
                  {
                    name     => 'run',
                    hostPath => {
                      path => '/run',
                    },
                  },
                  {
                    name     => 'cni',
                    hostPath => {
                      path => '/etc/kubernetes/cni/net.d',
                    },
                  },
                  {
                    name      => 'flannel-cfg',
                    configMap => {
                      name => 'flannel',
                    },
                  },
                  {
                    name     => 'host-cni-bin',
                    hostPath => {
                      path => '/opt/cni/bin',
                    },
                  },
                ],
              },
            },
            updateStrategy => {
              rollingUpdate => {
                maxUnavailable => 1,
              },
              type          => 'RollingUpdate',
            },
          },
        } + $flannel_daemonset_config;
    }
  }

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
