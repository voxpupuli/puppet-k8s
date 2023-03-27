# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::resources::flannel' do
  let(:pre_condition) do
    <<~PUPPET
      function assert_private() {}

      include ::k8s
      class { '::k8s::server':
        manage_etcd => true,
        manage_certs => true,
        manage_components => false,
        manage_resources => false,
        node_on_server => false,
      }
      include ::k8s::server::resources
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it { is_expected.to contain_kubectl_apply('flannel ServiceAccount') }
      it { is_expected.to contain_kubectl_apply('flannel ClusterRole') }
      it { is_expected.to contain_kubectl_apply('flannel ClusterRoleBinding') }
      it { is_expected.to contain_kubectl_apply('flannel ConfigMap') }
      it { is_expected.to contain_kubectl_apply('flannel DaemonSet') }
    end
  end
end
