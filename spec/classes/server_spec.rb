# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server' do
  let(:pre_condition) do
    <<~PUPPET
      include k8s
    PUPPET
  end

  let(:params) do
    {
      node_on_server: false,
      etcd_servers: ['https://localhost:2379']
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      context 'with node_on_server and custom node/proxy cert paths' do
        let(:params) do
          {
            node_on_server: true,
            etcd_servers: ['https://localhost:2379'],
            node_cert: '/node.crt',
            node_key: '/node.key',
            proxy_cert: '/kube-proxy.crt',
            proxy_key: '/kube-proxy.key',
          }
        end

        it do
          is_expected.to contain_class('k8s::node').with(
            node_cert: '/node.crt',
            node_key: '/node.key',
            proxy_cert: '/kube-proxy.crt',
            proxy_key: '/kube-proxy.key',
          )
        end
      end
    end
  end
end
