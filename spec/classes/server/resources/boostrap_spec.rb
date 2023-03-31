# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::resources::bootstrap' do
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

      it { is_expected.to contain_k8s__server__bootstrap_token('puppet') }

      it { is_expected.to contain_kubectl_apply('puppet:cluster-info:reader Role') }
      it { is_expected.to contain_kubectl_apply('system:certificates.k8s.io:certificatesigningrequests:nodeclient') }
      it { is_expected.to contain_kubectl_apply('system:certificates.k8s.io:certificatesigningrequests:selfnodeclient') }
      it { is_expected.to contain_kubectl_apply('system:certificates.k8s.io:certificatesigningrequests:selfnodeserver') }

      it { is_expected.to contain_kubectl_apply('puppet:cluster-info:reader RoleBinding') }
      it { is_expected.to contain_kubectl_apply('system-bootstrap-node-bootstrapper') }
      it { is_expected.to contain_kubectl_apply('system-bootstrap-approve-node-client-csr') }
      it { is_expected.to contain_kubectl_apply('system-bootstrap-node-renewal') }
      it { is_expected.to contain_kubectl_apply('system-bootstrap-node-server-renewal') }

      describe 'with local CA files' do
        let(:facts) { super().merge(k8s_ca: Base64.strict_encode64('This is actually a CA PEM')) }

        it { is_expected.to contain_kubectl_apply('cluster-info') }
      end
    end
  end
end
