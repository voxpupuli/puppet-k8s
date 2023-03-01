# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::etcd' do
  let(:params) do
    {
      generate_ca: true,
      manage_certs: true,
      manage_members: true
    }
  end
  let(:pre_condition) do
    <<~PUPPET
      function puppetdb_query(String[1] $data) {
        return [
          {
            certname => 'node.example.com',
            parameters => {
              etcd_name => 'node',
              initial_advertise_peer_urls => ['https://node.example.com:2380'],
            }
          }
        ]
      }

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

      it do
        %w[etcd-peer-ca etcd-client-ca].each do |ca|
          is_expected.to contain_k8s__server__tls__ca(ca)
        end
      end

      it do
        %w[etcd-peer etcd-client].each do |cert|
          is_expected.to contain_k8s__server__tls__cert(cert)
        end
      end

      it { is_expected.to contain_class('k8s::server::etcd::setup') }
      it { is_expected.to contain_k8s__server__etcd__member('node').with_peer_urls(['https://node.example.com:2380']) }
    end
  end
end
