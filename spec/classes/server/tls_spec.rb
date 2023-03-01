# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::tls' do
  let(:params) do
    {
      generate_ca: true,
      manage_certs: true
    }
  end
  let(:pre_condition) do
    <<~PUPPET
      include ::k8s
      class { '::k8s::server':
        manage_etcd => false,
        manage_certs => false,
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

      %w[kube-ca aggregator-ca].each do |ca|
        it { is_expected.to contain_k8s__server__tls__ca(ca) }
      end

      %w[
        kube-apiserver front-proxy-client
        apiserver-kubelet-client kube-controller-manager
        kube-scheduler kube-proxy node admin
      ].each do |cert|
        it { is_expected.to contain_k8s__server__tls__cert(cert) }
      end
    end
  end
end
