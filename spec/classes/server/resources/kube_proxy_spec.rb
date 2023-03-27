# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::resources::kube_proxy' do
  let(:pre_condition) do
    <<~PUPPET
      function assert_private() {}

      class { '::k8s':
        version => '1.26.1',
      }
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

  let(:content) { Psych.load(File.read('spec/fixtures/files/resources/kube-proxy.yaml')) }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it { is_expected.to contain_kubectl_apply('kube-proxy ClusterRoleBinding') }
      it { is_expected.to contain_kubectl_apply('kube-proxy ConfigMap') }

      it { is_expected.to contain_kubectl_apply('kube-proxy DaemonSet').with_content(content) }

      describe "with k8s < 1.23.0" do
        let(:pre_condition) do
          <<~PUPPET
          function assert_private() {}

          class { '::k8s':
            version => '1.22.10',
          }
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
        let(:content) { Psych.load(File.read('spec/fixtures/files/resources/kube-proxy-older.yaml')) }

        it { is_expected.to contain_kubectl_apply('kube-proxy DaemonSet').with_content(content) }
      end
    end
  end
end
