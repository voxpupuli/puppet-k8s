# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::etcd::setup' do
  let(:params) do
    {
      version: '3.6.0'
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
      class { '::k8s::server::etcd':
        manage_setup => false,
      }
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_archive('etcd').with(
          ensure: 'present',
          path: '/opt/k8s/archives/etcd-v3.6.0-linux-amd64.tar.gz',
          source: 'https://storage.googleapis.com/etcd/v3.6.0/etcd-v3.6.0-linux-amd64.tar.gz',
          extract: true,
          extract_command: 'tar xfz %s --strip-components=1',
          extract_path: '/opt/k8s/etcd-3.6.0',
          cleanup: true,
          creates: ['/opt/k8s/etcd-3.6.0/etcd', '/opt/k8s/etcd-3.6.0/etcdctl']
        )

        is_expected.to contain_file('/usr/local/bin/etcd').with(
          ensure: 'link',
          mode: '0755',
          replace: true,
          target: '/opt/k8s/etcd-3.6.0/etcd'
        ).that_notifies('Service[etcd]')

        is_expected.to contain_file('/usr/local/bin/etcdctl').with(
          ensure: 'link',
          mode: '0755',
          replace: true,
          target: '/opt/k8s/etcd-3.6.0/etcdctl'
        )
      end

      it { is_expected.to contain_user('etcd') }
      it { is_expected.to contain_group('etcd') }
      it { is_expected.to contain_file('/etc/etcd').with_ensure('directory') }
      it { is_expected.to contain_file('/var/lib/etcd').with_ensure('directory') }
      it { is_expected.to contain_file('/etc/etcd/etcd.conf') }
      it { is_expected.to contain_file('/etc/etcd/cluster.conf') }
      it { is_expected.to contain_systemd__unit_file('etcd.service') }
      it { is_expected.to contain_service('etcd').with_ensure('running').that_subscribes_to('File[/etc/etcd/etcd.conf]') }
    end
  end
end
