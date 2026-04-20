# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server' do
  let(:pre_condition) do
    <<~PUPPET
      function puppetdb_query(String[1] $q) {
        return [
          {
            certname => 'node.example.com',
            parameters => {
              advertise_client_urls => 'https://node.example.com:2380'
            }
          }
        ]
      }
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

      context 'with full default setup' do
        let(:params) do
          {
            etcd_servers: ['https://localhost:2379'],
            manage_etcd: true,
            manage_certs: true,
            manage_components: true,
            manage_resources: true,
            manage_signing: true,
            manage_kubeadm: true,
            manage_crictl: true,
            node_on_server: true,
          }
        end

        it { is_expected.to compile.with_all_deps }
      end

      context 'with full setup and manage_certs => false' do
        let(:params) do
          {
            etcd_servers: ['https://localhost:2379'],
            manage_etcd: true,
            manage_certs: false,
            manage_components: true,
            manage_resources: true,
            manage_signing: true,
            manage_kubeadm: true,
            manage_crictl: true,
            node_on_server: true,
          }
        end

        it { is_expected.to compile.with_all_deps }
      end
    end
  end
end
