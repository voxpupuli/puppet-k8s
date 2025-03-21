# @summary Generates and deploys the default CoreDNS DNS provider for Kubernetes
# @api private
#
# @param cluster_cidr The internal cluster CIDR to proxy for
# @param cni_image The Flannel CNI plugin image name to use
# @param cni_image_tag The Flannel CNI plugin image tag to use
# @param cni_registry The Flannel CNI plugin image registry to use
# @param daemonset_config Additional configuration to merge into the DaemonSet object
# @param ensure Whether the resource should be present or absent on the system
# @param image The Flannel image name to use
# @param image_pull_secrets the secrets to pull from private registries
# @param image_tag The Flannel image tag to use
# @param kubeconfig The path to the kubeconfig file to use
# @param net_config Additional configuration to merge into net-conf.json for Flannel
# @param registry The Flannel image registry to use
#
class k8s::server::resources::flannel (
  K8s::Ensure $ensure                 = $k8s::ensure,
  Stdlib::Unixpath $kubeconfig        = $k8s::server::resources::kubeconfig,
  K8s::CIDR $cluster_cidr             = $k8s::server::resources::cluster_cidr,
  String[1] $cni_registry             = $k8s::server::resources::flannel_cni_registry,
  String[1] $cni_image                = $k8s::server::resources::flannel_cni_image,
  String[1] $cni_image_tag            = $k8s::server::resources::flannel_cni_tag,
  String[1] $netpol_registry          = $k8s::server::resources::flannel_netpol_registry,
  String[1] $netpol_image             = $k8s::server::resources::flannel_netpol_image,
  String[1] $netpol_image_tag         = $k8s::server::resources::flannel_netpol_tag,
  String[1] $registry                 = $k8s::server::resources::flannel_registry,
  String[1] $image                    = $k8s::server::resources::flannel_image,
  String[1] $image_tag                = $k8s::server::resources::flannel_tag,
  Boolean $netpol                     = $k8s::server::resources::flannel_netpol,
  Hash[String,Data] $daemonset_config = $k8s::server::resources::flannel_daemonset_config,
  Optional[Array] $image_pull_secrets = $k8s::server::resources::image_pull_secrets,
  Hash[String,Data] $net_config       = {},
) {
  assert_private()

  $_cluster_cidr_v4 = flatten($cluster_cidr).filter |$cidr| { $cidr =~ Stdlib::IP::Address::V4::CIDR }
  $_cluster_cidr_v6 = flatten($cluster_cidr).filter |$cidr| { $cidr =~ Stdlib::IP::Address::V6::CIDR }

  $_cni_conf = {
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
  }
  $_net_conf = delete_undef_values(
    {
      'Network'     => $_cluster_cidr_v4[0],
      'IPv6Network' => $_cluster_cidr_v6[0],
      'EnableIPv4'  => !$_cluster_cidr_v4.empty(),
      'EnableIPv6'  => !$_cluster_cidr_v6.empty(),
      'Backend'     => {
        'Type' => 'vxlan',
      },
    } + $net_config
  )
  if $netpol {
    $_netpol_rules = [
      {
        apiGroups => ['networking.k8s.io'],
        resources => ['networkpolicies'],
        verbs     => ['list', 'watch'],
      },
      {
        apiGroups => ['pollicy.networking.k8s.io'],
        resources => ['adminnetworkpolicies', 'baselineadminnetworkpolicies'],
        verbs     => ['list', 'watch'],
      },
    ]
    $_netpol_containers = [
      {
        name            => 'kube-network-policies',
        image           => "${cni_registry}/${cni_image}:${cni_image_tag}",
        command         => ['/bin/netpol', '--hostname-override=$(MY_NODE_NAME)', '--v=2'],
        env             => [
          {
            name      => 'MY_NODE_NAME',
            valueFrom => {
              fieldRef => {
                fieldPath => 'spec.nodeName',
              },
            },
          },
        ],
        volumeMounts    => [
          {
            name      => 'lib-modules',
            mountPath => '/lib/modules',
            readOnly  => true,
          },
        ],
        resources       => {
          requests => {
            cpu    => '100m',
            memory => '50Mi',
          },
          limits => {
            cpu    => '100m',
            memory => '50Mi',
          },
        },
        securityContext => {
          privileged   => true,
          capabilities => {
            add => ['NET_ADMIN'],
          },
        },
      },
    ]
    $_netpol_volumes = [
      {
        name     => 'lib-modules',
        hostPath => {
          path => '/lib/modules',
        },
      },
    ]
  } else {
    $_netpol_rules = []
    $_netpol_containers = []
    $_netpol_volumes = []
  }

  kubectl_apply {
    default:
      ensure        => $ensure,
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
            apiGroups => [''],
            resources => ['pods','nodes','namespaces'],
            verbs     => ['list','watch'],
          },
          {
            apiGroups => [''],
            resources => ['nodes/status'],
            verbs     => ['patch'],
          },
          {
            apiGroups     => ['extensions'],
            resources     => ['podsecuritypolicies'],
            verbs         => ['use'],
            resourceNames => ['psp.flannel.unprivileged'],
          },
        ] + $_netpol_rules,
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
          'cni-conf.json' => $_cni_conf.to_json(),
          'net-conf.json' => $_net_conf.to_json(),
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
              'k8s-app' => 'flannel',
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
              affinity           => {
                nodeAffinity => {
                  requiredDuringSchedulingIgnoredDuringExecution => {
                    nodeSelectorTerms => [
                      {
                        matchExpressions => [
                          {
                            key      => 'kubernetes.io/os',
                            operator => 'In',
                            values   => ['linux'],
                          },
                        ],
                      },
                    ],
                  },
                },
              },
              hostNetwork        => true,
              priorityClassName  => 'system-node-critical',
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
              serviceAccountName => 'flannel',
              initContainers     => [
                {
                  name         => 'install-cni-plugin',
                  image        => "${cni_registry}/${cni_image}:${cni_image_tag}",
                  command      => ['cp'],
                  args         => [
                    '-f',
                    '/flannel',
                    '/opt/cni/bin/flannel',
                  ],
                  volumeMounts => [
                    {
                      name      => 'cni-plugin',
                      mountPath => '/opt/cni/bin',
                    },
                  ],
                },
                {
                  name         => 'install-cni',
                  image        => "${cni_registry}/${cni_image}:${cni_image_tag}",
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
              containers         => [
                {
                  name            => 'kube-flannel',
                  image           => "${registry}/${image}:${image_tag}",
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
                    {
                      name  => 'EVENT_QUEUE_DEPTH',
                      value => '5000',
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
                    {
                      name      => 'xtables-lock',
                      mountPath => '/run/xtables.lock',
                    },
                  ],
                },
              ] + $_netpol_containers,
              imagePullSecrets   => $image_pull_secrets,
              volumes            => [
                {
                  name     => 'run',
                  hostPath => {
                    path => '/run/flannel',
                    type => 'DirectoryOrCreate',
                  },
                },
                {
                  name     => 'cni-plugin',
                  hostPath => {
                    path => '/opt/cni/bin',
                  },
                },
                {
                  name     => 'cni',
                  hostPath => {
                    path => '/etc/cni/net.d',
                  },
                },
                {
                  name      => 'flannel-cfg',
                  configMap => {
                    name => 'flannel',
                  },
                },
                {
                  name     => 'xtables-lock',
                  hostPath => {
                    path => '/run/xtables.lock',
                    type => 'FileOrCreate',
                  },
                },
              ] + $_netpol_volumes,
            },
          },
          updateStrategy => {
            rollingUpdate => {
              maxUnavailable => 1,
            },
            type          => 'RollingUpdate',
          },
        },
      } + $daemonset_config;
  }
}
