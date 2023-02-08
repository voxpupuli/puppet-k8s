class k8s::server::resources(
  Stdlib::Unixpath $kubeconfig = '/root/.kube/config',

  Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR, Array[Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR]]] $cluster_cidr = $k8s::server::cluster_cidr,
  Variant[Stdlib::IP::Address::Nosubnet, Array[Stdlib::IP::Address::Nosubnet]] $dns_service_address = $k8s::server::dns_service_address,
  Stdlib::Unixpath $ca_cert = $k8s::server::tls::ca_cert,
  String[1] $cluster_domain = $k8s::server::cluster_domain,
  String[1] $master = $k8s::server::master,

  Boolean $manage_bootstrap = true,
  Boolean $manage_kube_proxy = $k8s::manage_kube_proxy,
  Boolean $manage_coredns = true,
  Boolean $manage_flannel = true,

  String[1] $kube_proxy_image = 'k8s.gcr.io/kube-proxy',
  String[1] $kube_proxy_tag = "v${k8s::version}",
  Hash[String,Data] $kube_proxy_daemonset_config = {},
  Hash[String,Data] $extra_kube_proxy_args = {},
  String[1] $coredns_image = 'coredns/coredns',
  String[1] $coredns_tag = '1.8.7',
  Hash[String,Data] $coredns_deployment_config = {},
  String[1] $flannel_cni_image = 'rancher/mirrored-flannelcni-flannel-cni-plugin',
  String[1] $flannel_cni_tag = 'v1.0.0',
  String[1] $flannel_image = 'rancher/mirrored-flannelcni-flannel',
  String[1] $flannel_tag = 'v0.16.1',
  Hash[String,Data] $flannel_daemonset_config = {},
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
                  }
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
              apiGroups     => [ '' ],
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
                'create'
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
                'create'
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
                'create'
              ],
            },
          ],
        };
    }

    kubectl_apply{
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
          }
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
          }
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
          }
        };
    }
  }

  if $manage_kube_proxy {
    # if version >= 1.23
    #   command = /go-runner
    #   args = --log-file=blah --also-stdout /usr/local/bin/kube-proxy
    # else
    #   command = /usr/local/bin/kube-proxy
    #   args = --logtostderr=false --alsologtostderr=true --log-file=blah

    kubectl_apply {
      default:
        kubeconfig    => $kubeconfig,
        provider      => 'kubectl',
        resource_name => 'kube-proxy',
        namespace     => 'kube-system';

      'kube-proxy ClusterRoleBinding':
        api_version   => 'rbac.authorization.k8s.io/v1',
        kind          => 'ClusterRoleBinding',
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
                apiVersion  => 'kubeproxy.config.k8s.io/v1alpha1',
                kind        => 'KubeProxyConfiguration',
                clusterCIDR => $cluster_cidr,
            }),
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
                    image           => "${kube_proxy_image}:${kube_proxy_tag}",
                    imagePullPolicy => 'IfNotPresent',
                    command         => [
                      '/usr/local/bin/kube-proxy',
                    ],
                    args            => k8s::format_arguments({
                        alsologtostderr   => true,
                        log_file          => '/var/log/kube-proxy.log',
                        cluster_cidr      => $cluster_cidr,
                        hostname_override => '$(NODE_NAME)',
                        kubeconfig        => '/var/lib/kube-proxy/kubeconfig',
                    } + $extra_kube_proxy_args),
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
        } + $kube_proxy_daemonset_config;
    }
  }

  if $manage_coredns {
    if $dns_service_address =~ Array[Stdlib::IP::Address::Nosubnet] {
      $_addn_coredns_svc_hash = {
        clusterIP  => $dns_service_address[0],
        clusterIPs => $dns_service_address,
      }
    } else {
      $_addn_coredns_svc_hash = {
        clusterIP => $dns_service_address,
      }
    }

    kubectl_apply {
      default:
        kubeconfig    => $kubeconfig,
        provider      => 'kubectl',
        resource_name => 'coredns',
        namespace     => 'kube-system';

      'coredns ServiceAccount':
        api_version => 'v1',
        kind        => 'ServiceAccount',
        content     => {
          metadata => {
            labels => {
              'kubernetes.io/managed-by' => 'puppet',
            },
          },
        };

      'coredns ClusterRole':
        api_version   => 'rbac.authorization.k8s.io/v1',
        kind          => 'ClusterRole',
        resource_name => 'system:coredns',
        content       => {
          metadata => {
            labels => {
              'kubernetes.io/bootstrapping' => 'rbac-defaults',
              'kubernetes.io/managed-by'    => 'puppet',
            },
          },
          rules    => [
            {
              apiGroups => [''],
              resources => ['endpoints','services','pods','namespaces'],
              verbs     => ['list','watch'],
            },
            {
              apiGroups => ['discovery.k8s.io'],
              resources => ['endpointslices'],
              verbs     => ['list','watch'],
            },
          ],
        };

      'coredns ClusterRoleBinding':
        api_version   => 'rbac.authorization.k8s.io/v1',
        kind          => 'ClusterRoleBinding',
        resource_name => 'system:coredns',
        content       => {
          metadata => {
            annotations => {
              'rbac.authorization.kubernetes.io/autoupdate' => 'true',
            },
            labels      => {
              'kubernetes.io/bootstrapping' => 'rbac-defaults',
              'kubernetes.io/managed-by'    => 'puppet',
            },
          },
          subjects => [
            {
              kind      => 'ServiceAccount',
              name      => 'coredns',
              namespace => 'kube-system',
            },
          ],
          roleRef  => {
            kind     => 'ClusterRole',
            name     => 'system:coredns',
            apiGroup => 'rbac.authorization.k8s.io',
          },
        };

      'coredns ConfigMap':
        api_version => 'v1',
        kind        => 'ConfigMap',
        content     => {
          metadata => {
            labels => {
              'kubernetes.io/managed-by' => 'puppet',
            },
          },
          data     => {
            'Corefile' => @("COREDNS"),
            .:53 {
              errors
              health {
                lameduck 5s
              }
              ready
              kubernetes ${cluster_domain} in-addr.arpa ip6.arpa {
                fallthrough in-addr.arpa ip6.arpa
              }
              prometheus :9153
              forward . /etc/resolv.conf {
                max_concurrent 1000
              }
              cache 30
              loop
              reload
              loadbalance
            }
            |-COREDNS
          },
        };

      'coredns Deployment':
        api_version => 'apps/v1',
        kind        => 'Deployment',
        content     => {
          metadata => {
            labels => {
              'k8s-app'                  => 'coredns',
              'kubernetes.io/name'       => 'CoreDNS',
              'kubernetes.io/managed-by' => 'puppet',
            },
          },
          spec     => {
            strategy => {
              type          => 'RollingUpdate',
              rollingUpdate => {
                maxUnavailable => 1,
              },
            },
            selector => {
              matchLabels => {
                'k8s-app'                  => 'coredns',
                'kubernetes.io/managed-by' => 'puppet',
              },
            },
            template => {
              metadata => {
                labels      => {
                  'k8s-app'                  => 'coredns',
                  'kubernetes.io/managed-by' => 'puppet',
                },
              },
              spec     => {
                affinity           => {
                  podAntiAffinity => {
                    preferredDuringSchedulingIgnoredDuringExecution => [
                      {
                        weight          => 100,
                        podAffinityTerm => {
                          labelSelector => {
                            matchExpressions => [
                              {
                                key      => 'k8s-app',
                                operator => 'In',
                                values   => [ 'coredns' ],
                              },
                            ],
                          },
                          topologyKey   => 'kubernetes.io/hostname',
                        },
                      },
                    ],
                  },
                },
                priorityClassName  => 'system-cluster-critical',
                serviceAccountName => 'coredns',
                tolerations        => [
                  {
                    key      => 'CriticalAddonsOnly',
                    operator => 'Exists',
                  },
                  {
                    key    => 'node-role.kubernetes.io/master',
                    effect => 'NoSchedule',
                  },
                ],
                nodeSelector       => {
                  'kubernetes.io/os' => 'linux',
                },
                containers         => [
                  {
                    name            => 'coredns',
                    image           => "${coredns_image}:${coredns_tag}",
                    imagePullPolicy => 'IfNotPresent',
                    resources       => {
                      limits   => {
                        memory => '170Mi',
                      },
                      requests => {
                        cpu    => '100m',
                        memory => '70Mi',
                      },
                    },
                    args            => [ '-conf', '/etc/coredns/Corefile' ],
                    volumeMounts    => [
                      {
                        name      => 'config-volume',
                        mountPath => '/etc/coredns',
                        readOnly  => true,
                      },
                    ],
                    ports           => [
                      {
                        name          => 'dns',
                        protocol      => 'UDP',
                        containerPort => 53
                      },
                      {
                        name          => 'dns-tcp',
                        protocol      => 'TCP',
                        containerPort => 53
                      },
                      {
                        name          => 'metrics',
                        protocol      => 'TCP',
                        containerPort => 9153
                      },
                    ],
                    livenessProbe   => {
                      httpGet             => {
                        path => '/health',
                        port => 8080,
                      },
                      initialDelaySeconds => 60,
                      timeoutSeconds      => 5,
                      successThreshold    => 1,
                      failureThreshold    => 5,
                    },
                    readinessProbe  => {
                      httpGet => {
                        path => '/ready',
                        port => 8181,
                      },
                    },
                    securityContext => {
                      allowPrivilegeEscalation => false,
                      capabilities             => {
                        add  => [ 'NET_BIND_SERVICE' ],
                        drop => [ 'all' ],
                      },
                      readOnlyRootFilesystem   => true,
                    },
                  },
                ],
                dnsPolicy          => 'Default',
                volumes            => [
                  {
                    name      => 'config-volume',
                    configMap => {
                      name  => 'coredns',
                      items => [
                        {
                          key  => 'Corefile',
                          path => 'Corefile',
                        },
                      ],
                    },
                  },
                ],
              },
            },
          },
        } + $coredns_deployment_config,
        require     => Kubectl_apply[
          'coredns ServiceAccount',
          'coredns ConfigMap',
        ];

      'coredns Service':
        api_version   => 'v1',
        kind          => 'Service',
        resource_name => 'kube-dns',
        content       => {
          metadata => {
            annotations => {
              'prometheus.io/port'   => '9153',
              'prometheus.io/scrape' => 'true',
            },
            labels      => {
              'k8s-app'                       => 'coredns',
              'kubernetes.io/cluster-service' => 'true',
              'kubernetes.io/name'            => 'CoreDNS',
              'kubernetes.io/managed-by'      => 'puppet',
            },
          },
          spec     => $_addn_coredns_svc_hash + {
            selector  => {
              'k8s-app' => 'coredns',
            },
            ports     => [
              {
                name     => 'dns',
                port     => 53,
                protocol => 'UDP',
              },
              {
                name     => 'dns-tcp',
                port     => 53,
                protocol => 'TCP',
              }
            ],
          },
        };
    }
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
            }
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
                    command         => [ '/opt/bin/flanneld' ],
                    args            => [ '--ip-masq', '--kube-subnet-mgr' ],
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
                        add => [ 'NET_ADMIN', 'NET_RAW' ],
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
                    command      => [ 'cp' ],
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
                    command      => [ 'cp' ],
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
          }
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
                }
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
