# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::etcd::member' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      peer_urls: ['http://localhost:4001'],
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_exec('Add namevar as member').with(
          environment: ['ETCDCTL_API=3'],
          command: 'etcdctl member add namevar --peer-urls="http://localhost:4001"',
          onlyif: 'etcdctl endpoint health',
          unless: %r{etcdctl -w fields member list | grep \\"Name\\" | grep namevar || \s+ etcdctl -w fields member list | grep \\"PeerURL\\" | grep http://localhost:4001},
          path: ['/bin', '/usr/bin', '/usr/local/bin']
        )
      end

      context 'with etcd installed' do
        let(:pre_condition) do
          <<~PUPPET
            service { 'etcd':
              ensure => running,
            }
          PUPPET
        end

        it do
          is_expected.to contain_exec('Add namevar as member').that_requires('Service[etcd]')
        end
      end
    end
  end
end
