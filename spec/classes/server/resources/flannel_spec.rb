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
      class { 'k8s::server::resources':
        manage_flannel => false,
      }
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) { { cluster_cidr: '10.0.0.0/16' } }

      let(:cni_conf) do
        {
          name: 'cbr0',
          cniVersion: '0.3.1',
          plugins: [
            {
              type: 'flannel',
              delegate: {
                hairpinMode: true,
                isDefaultGateway: true
              }
            },
            {
              type: 'portmap',
              capabilities: {
                portMappings: true
              }
            }
          ]
        }.to_json
      end
      let(:net_conf) do
        {
          Network: '10.0.0.0/16',
          EnableIPv4: true,
          EnableIPv6: false,
          Backend: {
            Type: 'vxlan'
          }
        }.to_json
      end

      let(:content) do
        {
          'metadata' => {
            'labels' => {
              'tier' => 'node',
              'k8s-app' => 'flannel',
              'kubernetes.io/managed-by' => 'puppet',
            }
          },
          'data' => {
            'cni-conf.json' => '{"name":"cbr0","cniVersion":"0.3.1","plugins":[{"type":"flannel","delegate":{"hairpinMode":true,"isDefaultGateway":true}},{"type":"portmap","capabilities":{"portMappings":true}}]}',
            'net-conf.json' => net_conf
          }
        }
      end

      it { is_expected.to compile }

      it { is_expected.to contain_kubectl_apply('flannel ServiceAccount') }
      it { is_expected.to contain_kubectl_apply('flannel ClusterRole') }
      it { is_expected.to contain_kubectl_apply('flannel ClusterRoleBinding') }
      it { is_expected.to contain_kubectl_apply('flannel DaemonSet') }

      describe 'with single-stack IPv4' do
        it do
          is_expected.to contain_kubectl_apply('flannel ConfigMap').
            with_ensure(:present).
            with_content(content)
        end
      end

      describe 'with single-stack IPv6' do
        let(:params) { { cluster_cidr: '2001:6b0:ffff::/48' } }
        let(:net_conf) do
          {
            IPv6Network: '2001:6b0:ffff::/48',
            EnableIPv4: false,
            EnableIPv6: true,
            Backend: {
              Type: 'vxlan'
            }
          }.to_json
        end

        it do
          is_expected.to contain_kubectl_apply('flannel ConfigMap').
            with_ensure(:present).
            with_content(content)
        end
      end

      describe 'with dual-stack IPv4+6' do
        let(:params) { { cluster_cidr: ['10.0.0.0/16', '2001:6b0:ffff::/48'] } }
        let(:net_conf) do
          {
            Network: '10.0.0.0/16',
            IPv6Network: '2001:6b0:ffff::/48',
            EnableIPv4: true,
            EnableIPv6: true,
            Backend: {
              Type: 'vxlan'
            }
          }.to_json
        end

        it do
          is_expected.to contain_kubectl_apply('flannel ConfigMap').
            with_ensure(:present).
            with_content(content)
        end
      end
    end
  end
end
