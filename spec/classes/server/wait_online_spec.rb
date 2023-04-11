# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::wait_online' do
  let(:pre_condition) do
    <<~PUPPET
      function assert_private() {}

      include ::k8s
      class { '::k8s::server':
        manage_etcd => false,
        manage_certs => true,
        manage_components => false,
        manage_resources => false,
        node_on_server => false,
      }
      class { '::k8s::server::apiserver':
        etcd_servers => [],
      }
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_exec('k8s-apiserver wait online').
          that_requires('Kubeconfig[/root/.kube/config]').
          that_requires('K8s::Binary[kubectl]').
          that_requires('Service[kube-apiserver]')
      end
    end
  end
end
