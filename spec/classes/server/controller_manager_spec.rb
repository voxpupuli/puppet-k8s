# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::controller_manager' do
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

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it { is_expected.to contain_kubeconfig('/srv/kubernetes/k8s-controller-manager.kubeconf') }

      it { is_expected.not_to contain_file('/etc/kubernetes/manifests/k8s-controller-manager.yaml') }
      it do
        is_expected.to contain_file('/etc/sysconfig/k8s-controller-manager')
          .with_content(
            <<~SYSCONF,
            ### NB: File managed by Puppet.
            ###     Any changes will be overwritten.
            #
            ## Kubernetes Controller Manager configuration
            #

            K8S_CONTROLLER_MANAGER_ARGS="--allocate-node-cidrs=true --cluster-cidr=10.0.0.0/16 --service-cluster-ip-range=10.1.0.0/24 --cluster-signing-cert-file=/etc/kubernetes/certs/ca.pem --cluster-signing-key-file=/etc/kubernetes/certs/ca.key --leader-elect=true --root-ca-file=/etc/kubernetes/certs/ca.pem --service-account-private-key-file=/etc/kubernetes/certs/service-account.key --feature-gates=RotateKubeletClientCertificate=true,RotateKubeletServerCertificate=true --kubeconfig=/srv/kubernetes/k8s-controller-manager.kubeconf"
            SYSCONF
          ).that_notifies('Service[k8s-controller-manager]')
      end
      it { is_expected.to contain_systemd__unit_file('k8s-controller-manager.service').that_notifies('Service[k8s-controller-manager]') }
      it do
        is_expected.to contain_service('k8s-controller-manager').with(
          ensure: 'running',
          enable: true,
        )
      end
    end
  end
end
