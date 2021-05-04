# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::apiserver' do
  let(:pre_condition) do
    <<~PUPPET
    function assert_private() {}
    function puppetdb_query(String[1] $data) {
      return [
        {
          certname => 'node.example.com',
          parameters => {
            advertise_client_urls => 'https://node.example.com:2380'
          }
        }
      ]
    }

    include ::k8s
    class { '::k8s::server':
      manage_etcd => true,
      manage_certs => true,
      manage_components => false,
      manage_resources => false,
      node_on_server => false,
    }
    PUPPET
  end
  let(:params) do
    {
      discover_etcd_servers: true
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it { is_expected.not_to contain_file('/etc/kubernetes/manifests/kube-apiserver.yaml') }

      it do
        is_expected.to contain_file('/etc/sysconfig/k8s-apiserver')
          .with_content(
            <<~SYSCONF,
            ### NB: File managed by Puppet.
            ###     Any changes will be overwritten.
            #
            ## Kubernetes API Server configuration
            #

            K8S_APISERVER_ARGS="--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeClaimResize,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ResourceQuota,Priority,NodeRestriction --advertise-address=172.16.254.254 --allow-privileged=true --anonymous-auth=false --authorization-mode=Node,RBAC --bind-address=:: --client-ca-file=/etc/kubernetes/certs/ca.pem --enable-bootstrap-token-auth=true --requestheader-client-ca-file=/etc/kubernetes/certs/aggregator-ca.pem --requestheader-allowed-names=front-proxy-client --requestheader-extra-headers-prefix=X-Remote-Extra- --requestheader-group-headers=X-Remote-Group --requestheader-username-headers=X-Remote-User --proxy-client-cert-file=/etc/kubernetes/certs/front-proxy-client.pem --proxy-client-key-file=/etc/kubernetes/certs/front-proxy-client.key --etcd-cafile=/etc/kubernetes/certs/etcd-ca.pem --etcd-certfile=/etc/kubernetes/certs/etcd.pem --etcd-keyfile=/etc/kubernetes/certs/etcd.key --etcd-servers=https://node.example.com:2380 --insecure-port=0 --kubelet-client-certificate=/etc/kubernetes/certs/apiserver-kubelet-client.pem --kubelet-client-key=/etc/kubernetes/certs/apiserver-kubelet-client.key --secure-port=6443 --service-account-key-file=/etc/kubernetes/certs/service-account.pub --service-cluster-ip-range=10.1.0.0/24 --tls-cert-file=/etc/kubernetes/certs/kube-apiserver.pem --tls-private-key-file=/etc/kubernetes/certs/kube-apiserver.key"
            SYSCONF
          )
          .that_notifies('Service[k8s-apiserver]')
      end
      it { is_expected.to contain_systemd__unit_file('k8s-apiserver.service').that_notifies('Service[k8s-apiserver]') }
      it do
        is_expected.to contain_service('k8s-apiserver').with(
          ensure: 'running',
          enable: true,
        )
      end
    end
  end
end
