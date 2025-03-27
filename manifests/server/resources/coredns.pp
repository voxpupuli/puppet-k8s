# @summary Generates and deploys the default CoreDNS DNS provider for Kubernetes
# @api private
#
# @param cluster_domain The cluster domain to use for the CoreDNS ConfigMap
# @param corefile_content The content to use for the CoreDNS ConfigMap
# @param deployment_config Additional configuration to merge into the Kubernetes Deployment object
# @param dns_service_address The address for the DNS service
# @param ensure Whether the resource should be present or absent on the target system
# @param hosts Additional host-style entries for the CoreDNS deployment to serve
# @param image The CoreDNS image name to use
# @param image_pull_secrets the secrets to pull from private registries
# @param image_tag The CoreDNS image tag to use
# @param kubeconfig The path to the kubeconfig to use for kubectl commands
# @param registry The CoreDNS image registry to use
# @param template_path The path to the template to use for the CoreDNS ConfigMap
# @param template_variables The variables to use for the CoreDNS ConfigMap template
#
class k8s::server::resources::coredns (
  K8s::Ensure $ensure                    = $k8s::ensure,
  Stdlib::Fqdn $cluster_domain           = $k8s::server::resources::cluster_domain,
  Stdlib::Unixpath $kubeconfig           = $k8s::server::resources::kubeconfig,
  K8s::IP_addresses $dns_service_address = $k8s::server::resources::dns_service_address,
  String[1] $registry                    = $k8s::server::resources::coredns_registry,
  String[1] $image                       = $k8s::server::resources::coredns_image,
  String[1] $image_tag                   = $k8s::server::resources::coredns_tag,
  Optional[Array] $image_pull_secrets    = $k8s::server::resources::image_pull_secrets,
  Hash[String,Data] $deployment_config   = $k8s::server::resources::coredns_deployment_config,
  Array[String[1]] $hosts                = [],
  String[1] $template_path               = 'k8s/server/resources/coredns_corefile.epp',
  Optional[String[1]] $corefile_content  = undef,
  Hash[String, Any] $template_variables  = { cluster_domain => $cluster_domain },
) {
  assert_private()

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

  $_hosts = $hosts.join("\n")

  if $corefile_content {
    $_corefile_content = $corefile_content
  } else {
    $_corefile_content = epp($template_path, $template_variables)
  }

  kubectl_apply {
    default:
      ensure        => $ensure,
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
          'Corefile'    => $_corefile_content,
          'PuppetHosts' => $_hosts,
        },
      };

    'coredns Deployment':
      api_version => 'apps/v1',
      kind        => 'Deployment',
      content     => {
        metadata => {
          labels => {
            'k8s-app'                  => 'kube-dns',
            'kubernetes.io/name'       => 'CoreDNS',
            'app.kubernetes.io/name'   => 'coredns',
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
              'k8s-app'                => 'kube-dns',
              'app.kubernetes.io/name' => 'coredns',
            },
          },
          template => {
            metadata => {
              labels      => {
                'k8s-app'                  => 'kube-dns',
                'app.kubernetes.io/name'   => 'coredns',
                'kubernetes.io/managed-by' => 'puppet',
              },
            },
            spec     => {
              affinity           => {
                podAntiAffinity => {
                  requiredDuringSchedulingIgnoredDuringExecution => [
                    {
                      labelSelector => {
                        matchExpressions => [
                          {
                            key      => 'k8s-app',
                            operator => 'In',
                            values   => ['kube-dns'],
                          },
                        ],
                      },
                      topologyKey   => 'kubernetes.io/hostname',
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
              ],
              nodeSelector       => {
                'kubernetes.io/os' => 'linux',
              },
              containers         => [
                {
                  name            => 'coredns',
                  image           => "${registry}/${image}:${image_tag}",
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
                  args            => ['-conf', '/etc/coredns/Corefile'],
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
                      add  => ['NET_BIND_SERVICE'],
                      drop => ['all'],
                    },
                    readOnlyRootFilesystem   => true,
                  },
                },
              ],
              imagePullSecrets   => $image_pull_secrets,
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
                      {
                        key  => 'PuppetHosts',
                        path => 'PuppetHosts',
                      },
                    ],
                  },
                },
              ],
            },
          },
        },
      } + $deployment_config,
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
            'k8s-app'                       => 'kube-dns',
            'kubernetes.io/cluster-service' => 'true',
            'kubernetes.io/name'            => 'CoreDNS',
            'app.kubernetes.io/name'        => 'coredns',
            'kubernetes.io/managed-by'      => 'puppet',
          },
        },
        spec     => $_addn_coredns_svc_hash + {
          selector => {
            'k8s-app'                => 'kube-dns',
            'app.kubernetes.io/name' => 'coredns',
          },
          ports    => [
            {
              name     => 'dns',
              port     => 53,
              protocol => 'UDP',
            },
            {
              name     => 'dns-tcp',
              port     => 53,
              protocol => 'TCP',
            },
            {
              name     => 'metrics',
              port     => 9153,
              protocol => 'TCP',
            },
          ],
        },
      };
  }
}
