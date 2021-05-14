class k8s::server::apiserver(
  Enum['present', 'absent'] $ensure = $k8s::server::ensure,

  Hash[String, Data] $arguments = {},

  Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR] $service_cluster_cidr = $k8s::service_cluster_cidr,

  Optional[Array[Stdlib::HTTPUrl]] $etcd_servers = undef,
  Boolean $discover_etcd_servers = $k8s::puppetdb_discovery,
  Boolean $manage_firewall = $k8s::server::manage_firewall,

  Stdlib::Unixpath $cert_path = $k8s::server::tls::cert_path,
  Stdlib::Unixpath $ca_cert = $k8s::server::tls::ca_cert,
  Stdlib::Unixpath $aggregator_ca_cert = $k8s::server::tls::aggregator_ca_cert,
  Stdlib::Unixpath $serviceaccount_public = "${cert_path}/service-account.pub",
  Stdlib::Unixpath $apiserver_cert = "${cert_path}/kube-apiserver.pem",
  Stdlib::Unixpath $apiserver_key = "${cert_path}/kube-apiserver.key",
  Stdlib::Unixpath $front_proxy_cert = "${cert_path}/front-proxy-client.pem",
  Stdlib::Unixpath $front_proxy_key = "${cert_path}/front-proxy-client.key",
  Stdlib::Unixpath $apiserver_client_cert = "${cert_path}/apiserver-kubelet-client.pem",
  Stdlib::Unixpath $apiserver_client_key = "${cert_path}/apiserver-kubelet-client.key",
  Stdlib::Unixpath $etcd_ca = "${cert_path}/etcd-ca.pem",
  Stdlib::Unixpath $etcd_cert = "${cert_path}/etcd.pem",
  Stdlib::Unixpath $etcd_key = "${cert_path}/etcd.key",
) {
  assert_private()

  k8s::binary { 'kube-apiserver':
    ensure => $ensure,
  }

  if $discover_etcd_servers and !$etcd_servers {
    # Needs the PuppetDB terminus installed
    $pql_query = @("PQL")
    resources[certname,parameters] {
      type = 'Class' and
      title = 'K8s::Server::Etcd::Setup' and
      nodes {
        resources {
          type = 'Class' and
          title = 'K8s::Server::Etcd' and
          parameters.cluster_name = '${k8s::server::etcd::cluster_name}'
        }
      }
      order by certname
    }
    | - PQL

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
      advertise_address                  => fact('networking.ip'),
      allow_privileged                   => true,
      anonymous_auth                     => true,
      authorization_mode                 => [ 'Node', 'RBAC' ],
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
      feature_gates                      => {
        'RotateKubeletClientCertificate' => true,
        'RotateKubeletServerCertificate' => true,
      },
  } + $_discovery + $_addn_args + $arguments)

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
                  'node-role.kubernetes.io/master' => '',
                },
                tolerations     => [
                  {
                    key      => 'node-role.kubernetes.io/master',
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
                  runAsGroup   => 888,
                  runAsUser    => 888,
                },
              },
            },
            updateStrategy => {
              rollingUpdate => {
                maxUnavailable => 1,
              },
              type          => 'RollingUpdate'
            },
          },
      }),
    }
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
        user  => kube,
        group => kube,
      }),
      require => [
        File["${_sysconfig_path}/kube-apiserver"],
        User['kube'],
      ],
      notify  => Service['kube-apiserver'],
    }
    service { 'kube-apiserver':
      ensure    => stdlib::ensure($ensure, 'service'),
      enable    => true,
      subscribe => K8s::Binary['kube-apiserver'],
    }

    Service['kube-apiserver'] -> Kubectl_apply<| |>
    [ 'kube-apiserver', 'front-proxy-client', 'apiserver-kubelet-client' ].each |$cert| {
      if defined(K8s::Server::Tls::Cert[$cert]) {
        K8s::Server::Tls::Cert[$cert] ~> Service['kube-apiserver']
      }
    }
  }

  if $manage_firewall {
    firewalld_service { 'Allow k8s apiserver access':
      ensure  => $ensure,
      zone    => 'public',
      service => 'kube-apiserver',
    }
  }
}
