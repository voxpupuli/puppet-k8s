# @summary Generates and deploys the default kube-proxy service for Kubernetes
#
# @param cluster_cidr The internal cluster CIDR to proxy for
# @param image The kube-proxy image name to use
# @param image_tag The kube-proxy image tag to use
# @param daemonset_config Additional configuration to merge into the DaemonSet object
# @param extra_args Additional arguments to specify to the kube-proxy application
# @param extra_config Additional configuration data to apply to the kube-proxy configuration file
class k8s::server::resources::kube_proxy (
  K8s::Ensure $ensure                    = $k8s::ensure,
  Stdlib::Unixpath $kubeconfig           = $k8s::server::resources::kubeconfig,
  K8s::CIDR $cluster_cidr                = $k8s::server::resources::cluster_cidr,
  String[1] $image                       = $k8s::server::resources::kube_proxy_image,
  String[1] $image_tag                   = $k8s::server::resources::kube_proxy_tag,
  Hash[String,Data] $daemonset_config    = {},
  Hash[String,Data] $extra_args          = {},
  Hash[String,Data] $extra_config        = {},
) {
  assert_private()

  if versioncmp($k8s::version, '1.23.0') >= 0 {
    $_container_command = '/go-runner'
    $_container_preargs = k8s::format_arguments({
        log_file    => '/var/log/kube-proxy.log',
        also_stdout => true,
    }) + ['--', '/usr/local/bin/kube-proxy']
  } else {
    $_container_command = '/usr/local/bin/kube-proxy'
    $_container_preargs = k8s::format_arguments({
        alsologtostderr => true,
        log_file        => '/var/log/kube-proxy.log',
    })
  }

  $_cluster_cidr = flatten($cluster_cidr).join(',')

  kubectl_apply {
    default:
      ensure        => $ensure,
      kubeconfig    => $kubeconfig,
      provider      => 'kubectl',
      resource_name => 'kube-proxy',
      namespace     => 'kube-system';

    'kube-proxy ServiceAccount':
      api_version => 'v1',
      kind        => 'ServiceAccount',
      content     => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
      };

    'kube-proxy ClusterRoleBinding':
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

    ## Default kube-proxy configuration
    # ---
    # apiVersion: kubeproxy.config.k8s.io/v1alpha1
    # bindAddress: 0.0.0.0
    # bindAddressHardFail: false
    # clientConnection:
    #   acceptContentTypes: ""
    #   burst: 10
    #   contentType: application/vnd.kubernetes.protobuf
    #   kubeconfig: ""
    #   qps: 5
    # clusterCIDR: ""
    # configSyncPeriod: 15m0s
    # conntrack:
    #   maxPerCore: 32768
    #   min: 131072
    #   tcpCloseWaitTimeout: 1h0m0s
    #   tcpEstablishedTimeout: 24h0m0s
    # detectLocalMode: ""
    # enableProfiling: false
    # healthzBindAddress: 0.0.0.0:10256
    # hostnameOverride: ""
    # iptables:
    #   masqueradeAll: false
    #   masqueradeBit: 14
    #   minSyncPeriod: 1s
    #   syncPeriod: 30s
    # ipvs:
    #   excludeCIDRs: null
    #   minSyncPeriod: 0s
    #   scheduler: ""
    #   strictARP: false
    #   syncPeriod: 30s
    #   tcpFinTimeout: 0s
    #   tcpTimeout: 0s
    #   udpTimeout: 0s
    # kind: KubeProxyConfiguration
    # metricsBindAddress: 127.0.0.1:10249
    # mode: ""
    # nodePortAddresses: null
    # oomScoreAdj: -999
    # portRange: ""
    # showHiddenMetricsForVersion: ""
    # udpIdleTimeout: 250ms
    # winkernel:
    #   enableDSR: false
    #   networkName: ""
    #   sourceVip: ""

    'kube-proxy ConfigMap':
      api_version => 'v1',
      kind        => 'ConfigMap',
      content     => {
        metadata => {
          labels => {
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        data     => {
          'kube-proxy.conf' => to_yaml({
              apiVersion       => 'kubeproxy.config.k8s.io/v1alpha1',
              kind             => 'KubeProxyConfiguration',
              clusterCIDR      => flatten($cluster_cidr).join(','),
              clientConnection => {
                kubeconfig => '/var/lib/kube-proxy/kubeconfig',
              },
          } + $extra_config),
        },
      };

    'kube-proxy DaemonSet':
      api_version => 'apps/v1',
      kind        => 'DaemonSet',
      content     => {
        metadata => {
          labels => {
            tier                       => 'node',
            'k8s-app'                  => 'kube-proxy',
            'kubernetes.io/managed-by' => 'puppet',
          },
        },
        spec     => {
          selector       => {
            matchLabels => {
              tier                       => 'node',
              'k8s-app'                  => 'kube-proxy',
              'kubernetes.io/managed-by' => 'puppet',
            },
          },
          template       => {
            metadata => {
              labels => {
                tier                       => 'node',
                'k8s-app'                  => 'kube-proxy',
                'kubernetes.io/managed-by' => 'puppet',
              },
            },
            spec     => {
              containers         => [
                {
                  name            => 'kube-proxy',
                  image           => "${image}:${image_tag}",
                  imagePullPolicy => 'IfNotPresent',
                  command         => [
                    $_container_command,
                  ],
                  args            => delete_undef_values(
                    $_container_preargs +
                    k8s::format_arguments(
                      {
                        hostname_override => '$(NODE_NAME)',
                        config            => '/var/lib/kube-proxy/kube-proxy.conf',
                      } + $extra_args
                    )
                  ),
                  env             => [
                    {
                      name      => 'NODE_NAME',
                      valueFrom => {
                        fieldRef => {
                          fieldPath => 'spec.nodeName',
                        },
                      },
                    },
                  ],
                  resources       => {
                    requests => {
                      cpu => '100m',
                    },
                  },
                  securityContext => {
                    privileged => true,
                  },
                  volumeMounts    => [
                    {
                      mountPath => '/var/lib/kube-proxy/kube-proxy.conf',
                      name      => 'kube-proxy',
                      subPath   => 'kube-proxy.conf',
                      readOnly  => true,
                    },
                    {
                      mountPath => '/var/lib/kube-proxy/kubeconfig',
                      name      => 'kubeconfig',
                      subPath   => 'kubeconfig',
                      readOnly  => true,
                    },
                    {
                      mountPath => '/lib/modules',
                      name      => 'lib-modules',
                      readOnly  => true,
                    },
                    # {
                    #   mountPath => '/etc/ssl/certs',
                    #   name      => 'ca-certs-host',
                    #   readOnly  => true,
                    # },
                    {
                      mountPath => '/run/xtables.lock',
                      name      => 'iptables-lock',
                    },
                  ],
                }
              ],
              hostNetwork        => true,
              priorityClassName  => 'system-node-critical',
              serviceAccountName => 'kube-proxy',
              tolerations        => [
                {
                  key      => 'CriticalAddonsOnly',
                  operator => 'Exists',
                },
                {
                  effect   => 'NoSchedule',
                  operator => 'Exists',
                },
                {
                  effect   => 'NoExecute',
                  operator => 'Exists',
                },
              ],
              volumes            => [
                {
                  name     => 'logfile',
                  hostPath => {
                    path => '/var/log/kube-proxy.log',
                    type => 'FileOrCreate',
                  },
                },
                {
                  name     => 'lib-modules',
                  hostPath => {
                    path => '/lib/modules',
                    type => 'Directory',
                  },
                },
                {
                  name     => 'iptables-lock',
                  hostPath => {
                    path => '/run/xtables.lock',
                    type => 'FileOrCreate',
                  },
                },
                # {
                #   name     => 'ca-certs-host',
                #   hostPath => {
                #     path => '/usr/share/ca-certificates',
                #     type => 'Directory',
                #   },
                # },
                {
                  name      => 'kube-proxy',
                  configMap => {
                    name => 'kube-proxy',
                  },
                },
                {
                  name      => 'kubeconfig',
                  configMap => {
                    name => 'kubeconfig-in-cluster',
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
      } + $daemonset_config;
  }
}
