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

      it { is_expected.to contain_kubeconfig('/srv/kubernetes/kube-controller-manager.kubeconf') }

      it { is_expected.not_to contain_file('/etc/kubernetes/manifests/kube-controller-manager.yaml') }
      it do
        sysconf = '/etc/sysconfig'
        sysconf = '/etc/default' if os_facts['os']['family'] == 'Debian'

        is_expected.to contain_file(File.join sysconf, 'kube-controller-manager')
          .with_content(
            <<~SYSCONF,
            ### NB: File managed by Puppet.
            ###     Any changes will be overwritten.
            #
            ## Kubernetes Controller Manager configuration
            #

            KUBE_CONTROLLER_MANAGER_ARGS="--allocate-node-cidrs=true --controllers=*,bootstrapsigner,tokencleaner --cluster-cidr=10.0.0.0/16 --service-cluster-ip-range=10.1.0.0/24 --cluster-signing-cert-file=/etc/kubernetes/certs/ca.pem --cluster-signing-key-file=/etc/kubernetes/certs/ca.key --leader-elect=true --root-ca-file=/etc/kubernetes/certs/ca.pem --service-account-private-key-file=/etc/kubernetes/certs/service-account.key --feature-gates=RotateKubeletClientCertificate=true,RotateKubeletServerCertificate=true --kubeconfig=/srv/kubernetes/kube-controller-manager.kubeconf"
            SYSCONF
          ).that_notifies('Service[kube-controller-manager]')
      end
      it { is_expected.to contain_systemd__unit_file('kube-controller-manager.service').that_notifies('Service[kube-controller-manager]') }
      it do
        is_expected.to contain_service('kube-controller-manager').with(
          ensure: 'running',
          enable: true,
        )
      end
    end
  end
end
