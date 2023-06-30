# @summary Installs and configures a Kubernetes apiserver
#
# @param advertise_address bind address of the apiserver
# @param aggregator_ca_cert
# @param apiserver_cert path to the apiserver cert file
# @param apiserver_client_cert path to the apiserver client cert file
# @param apiserver_client_key path to the apiserver client key file
# @param apiserver_key path to the apiserver cert file
# @param arguments
# @param ca_cert path to the ca cert
# @param cert_path path to cert files
# @param discover_etcd_servers enable puppetdb resource searching
# @param ensure set ensure for installation or deinstallation
# @param etcd_ca path to the etcd ca cert file
# @param etcd_cert path to the etcd cert file
# @param etcd_cluster_name name of the etcd cluster for searching its nodes in the puppetdb
# @param etcd_key path to the etcd key file
# @param etcd_servers list etcd servers if no puppetdb is used
# @param firewall_type define the type of firewall to use
# @param front_proxy_cert
# @param front_proxy_key
# @param manage_firewall whether to manage firewall or not
# @param puppetdb_discovery_tag enable puppetdb resource searching
# @param service_cluster_cidr
# @param serviceaccount_private
# @param serviceaccount_public
#
class k8s::server::apiserver (
  K8s::Ensure $ensure = $k8s::server::ensure,

  Hash[String, Data] $arguments = {},

  K8s::CIDR $service_cluster_cidr = $k8s::service_cluster_cidr,

  Optional[Array[Stdlib::HTTPUrl]] $etcd_servers = $k8s::server::etcd_servers,
  Boolean $discover_etcd_servers                 = $k8s::puppetdb_discovery,
  Boolean $manage_firewall                       = $k8s::server::manage_firewall,
  String $puppetdb_discovery_tag                 = $k8s::server::puppetdb_discovery_tag,
  Stdlib::Unixpath $cert_path              = $k8s::server::tls::cert_path,
  Stdlib::Unixpath $ca_cert                = $k8s::server::tls::ca_cert,
  Stdlib::Unixpath $aggregator_ca_cert     = $k8s::server::tls::aggregator_ca_cert,
  Stdlib::Unixpath $serviceaccount_public  = "${cert_path}/service-account.pub",
  Stdlib::Unixpath $serviceaccount_private = "${cert_path}/service-account.key",
  Stdlib::Unixpath $apiserver_cert         = "${cert_path}/kube-apiserver.pem",
  Stdlib::Unixpath $apiserver_key          = "${cert_path}/kube-apiserver.key",
  Stdlib::Unixpath $front_proxy_cert       = "${cert_path}/front-proxy-client.pem",
  Stdlib::Unixpath $front_proxy_key        = "${cert_path}/front-proxy-client.key",
  Stdlib::Unixpath $apiserver_client_cert  = "${cert_path}/apiserver-kubelet-client.pem",
  Stdlib::Unixpath $apiserver_client_key   = "${cert_path}/apiserver-kubelet-client.key",
  Stdlib::Unixpath $etcd_ca                = "${cert_path}/etcd-ca.pem",
  Stdlib::Unixpath $etcd_cert              = "${cert_path}/etcd.pem",
  Stdlib::Unixpath $etcd_key               = "${cert_path}/etcd.key",

  Stdlib::IP::Address::Nosubnet $advertise_address = fact('networking.ip'),
  Optional[K8s::Firewall] $firewall_type           = $k8s::server::firewall_type,
  String[1] $etcd_cluster_name                     = $k8s::server::etcd_cluster_name,
) {
  assert_private()

  k8s::binary { 'kube-apiserver':
    ensure => $ensure,
  }

  unless $discover_etcd_servers or $etcd_servers {
    fail('please specify $etcd_servers or activate $discover_etcd_servers')
  }

  if $discover_etcd_servers and !$etcd_servers {
    # Needs the PuppetDB terminus installed
    $pql_query = [
      'resources[certname,parameters] {',
      '  type = \'Class\' and',
      '  title = \'K8s::Server::Etcd::Setup\' and',
      '  nodes {',
      '    resources {',
      '      type = \'Class\' and',
      '      title = \'K8s::Server::Etcd\' and',
      "      parameters.cluster_name = '${etcd_cluster_name}' and",
      "      parameters.puppetdb_discovery_tag = '${puppetdb_discovery_tag}'",
      '    }',
      '  }',
      '  order by certname',
      '}',
    ].join(' ')

    $cluster_nodes = puppetdb_query($pql_query)
    $_discovery = {
      etcd_servers => sort(flatten($cluster_nodes.map |$node| {
            $node['parameters']['advertise_client_urls']
      })),
    }
  } else {
    $_discovery = {}
  }

  if $k8s::packaging == 'container' {
    $_addn_args = {
      advertise_address => '$(POD_IP)',
      bind_address      => '0.0.0.0', # TODO dual-stack support
    }
  } else {
    $_addn_args = {}
  }

  if versioncmp($k8s::version, '1.20') >= 0 {
    $_service_account = {
      service_account_signing_key_file => $serviceaccount_private,
      service_account_issuer           => 'https://kubernetes.default.svc.cluster.local',
    }
  } else {
    $_service_account = {}
  }

  $_args = k8s::format_arguments({
      enable_admission_plugins           => [
        'NamespaceLifecycle',
        'LimitRanger',
        'ServiceAccount',
        'PersistentVolumeClaimResize',
        'DefaultStorageClass',
        'DefaultTolerationSeconds',
        'MutatingAdmissionWebhook',
        'ResourceQuota',
        'Priority',
        'NodeRestriction',
      ],
      advertise_address                  => $advertise_address,
      allow_privileged                   => true,
      anonymous_auth                     => true,
      authorization_mode                 => ['Node', 'RBAC'],
      bind_address                       => '::',
      client_ca_file                     => $ca_cert,
      enable_bootstrap_token_auth        => true,
      requestheader_client_ca_file       => $aggregator_ca_cert,
      requestheader_allowed_names        => 'front-proxy-client',
      requestheader_extra_headers_prefix => 'X-Remote-Extra-',
      requestheader_group_headers        => 'X-Remote-Group',
      requestheader_username_headers     => 'X-Remote-User',
      proxy_client_cert_file             => $front_proxy_cert,
      proxy_client_key_file              => $front_proxy_key,
      etcd_cafile                        => $etcd_ca,
      etcd_certfile                      => $etcd_cert,
      etcd_keyfile                       => $etcd_key,
      etcd_servers                       => $etcd_servers,
      kubelet_client_certificate         => $apiserver_client_cert,
      kubelet_client_key                 => $apiserver_client_key,
      secure_port                        => 6443,
      service_account_key_file           => $serviceaccount_public,
      service_cluster_ip_range           => $service_cluster_cidr,
      tls_cert_file                      => $apiserver_cert,
      tls_private_key_file               => $apiserver_key,
  } + $_discovery + $_addn_args + $_service_account + $arguments)

  if $k8s::packaging == 'container' {
    $_image = "${k8s::container_registry}/${k8s::container_image}:${pick($k8s::container_image_tag, $k8s::version)}"
    file { '/etc/kubernetes/manifests/kube-apiserver.yaml':
      ensure  => $ensure,
      content => to_yaml({
          apiVersion => 'apps/v1',
          kind       => 'DaemonSet',
          metadata   => {
            name      => 'kube-apiserver',
            namespace => 'kube-system',
            labels    => {
              'tier'    => 'control-plane',
              'k8s-app' => 'kube-apiserver',
            },
          },
          spec       => {
            selector       => {
              matchLabels => {
                'tier'    => 'control-plane',
                'k8s-app' => 'kube-apiserver',
              },
            },
            template       => {
              metadata => {
                labels => {
                  'tier'    => 'control-plane',
                  'k8s-app' => 'kube-apiserver',
                },
              },
              spec     => {
                containers      => [
                  {
                    name         => 'kube-apiserver',
                    image        => $_image,
                    command      => [
                      '/hyperkube',
                      'kube-apiserver',
                    ] + $_args,
                    env          => [
                      {
                        name      => 'POD_IP',
                        valueFrom => {
                          fieldRef => {
                            fieldPath => 'status.podIP',
                          },
                        },
                      },
                    ],
                    volumeMounts => [
                      {
                        mountPath => '/etc/ssl/certs',
                        name      => 'ssl-certs-host',
                        readOnly  => true,
                      },
                      {
                        mountPath => $cert_path,
                        name      => 'ssl-certs',
                        readOnly  => true,
                      },
                    ],
                  },
                ],
                hostNetwork     => true,
                nodeSelector    => {
                  'node-role.kubernetes.io/control-plane' => '',
                },
                tolerations     => [
                  {
                    key      => 'node-role.kubernetes.io/control-plane',
                    operator => 'Exists',
                    effect   => 'NoSchedule',
                  },
                ],
                volumes         => [
                  {
                    name     => 'ssl-certs-host',
                    hostPath => {
                      path => '/etc/ssl/certs',
                    },
                  },
                  {
                    name     => 'ssl-certs',
                    hostPath => {
                      path => $cert_path,
                    },
                  },
                ],
                securityContext => {
                  runAsNonRoot => true,
                  runAsGroup   => $k8s::uid,
                  runAsUser    => $k8s::gid,
                },
              },
            },
            updateStrategy => {
              rollingUpdate => {
                maxUnavailable => 1,
              },
              type          => 'RollingUpdate',
            },
          },
      }),
    }
    # TODO: Create a dummy kube-apiserver service that just requires kubelet
  } else {
    $_sysconfig_path = pick($k8s::sysconfig_path, '/etc/sysconfig')
    file { "${_sysconfig_path}/kube-apiserver":
      content => epp('k8s/sysconfig.epp', {
          comment               => 'Kubernetes API Server configuration',
          environment_variables => {
            'KUBE_APISERVER_ARGS' => $_args.join(' '),
          },
      }),
      notify  => Service['kube-apiserver'],
    }
    systemd::unit_file { 'kube-apiserver.service':
      ensure  => $ensure,
      content => epp('k8s/service.epp', {
          name  => 'kube-apiserver',

          desc  => 'Kubernetes API Server',
          doc   => 'https://github.com/GoogleCloudPlatform/kubernetes',

          dir   => '/srv/kubernetes',
          bin   => 'kube-apiserver',
          user  => $k8s::user,
          group => $k8s::group,
      }),
      require => [
        File["${_sysconfig_path}/kube-apiserver"],
        User[$k8s::user],
      ],
      notify  => Service['kube-apiserver'],
    }
    Service <| title == 'etcd' |>
    -> service { 'kube-apiserver':
      ensure    => stdlib::ensure($ensure, 'service'),
      enable    => true,
      subscribe => K8s::Binary['kube-apiserver'],
    }

    ['kube-apiserver', 'front-proxy-client', 'apiserver-kubelet-client'].each |$cert| {
      if defined(K8s::Server::Tls::Cert[$cert]) {
        K8s::Server::Tls::Cert[$cert] ~> Service['kube-apiserver']
      }
    }
  }

  if $manage_firewall {
    if $facts['firewalld_version'] {
      $_firewall_type = pick($firewall_type, 'firewalld')
    } else {
      $_firewall_type = pick($firewall_type, 'iptables')
    }

    case $_firewall_type {
      'firewalld' : {
        firewalld_service { 'Allow k8s apiserver access':
          ensure  => $ensure,
          zone    => 'public',
          service => 'kube-apiserver',
        }
      }
      'iptables': {
        include firewall

        firewall { '100 allow k8s apiserver access':
          dport  => 6443,
          proto  => 'tcp',
          action => 'accept',
        }
      }
      default: {}
    }
  }
}
