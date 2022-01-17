# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::node::kube_proxy' do
  let(:pre_condition) do
    <<~PUPPET
    function assert_private() {}

    include ::k8s
    class { '::k8s::node':
      manage_kubelet => false,
      manage_proxy => false,
    }
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it do
        sysconf = '/etc/sysconfig'
        sysconf = '/etc/default' if os_facts['os']['family'] == 'Debian'

        is_expected.to contain_file(File.join(sysconf, 'kube-proxy'))
          .that_notifies('Service[kube-proxy]')
      end
      it { is_expected.to contain_systemd__unit_file('kube-proxy.service').that_notifies('Service[kube-proxy]') }
      it { is_expected.to contain_service('kube-proxy') }

      context 'with cert auth' do
        let(:params) do
          {
            auth: 'cert',
            ca_cert: '/tmp/ca.pem',
            cert: '/tmp/cert.pem',
            key: '/tmp/key.pem',
          }
        end

        it do
          is_expected.to contain_kubeconfig('/srv/kubernetes/kube-proxy.kubeconf')
            .with_ca_cert('/tmp/ca.pem')
            .with_client_cert('/tmp/cert.pem')
            .with_client_key('/tmp/key.pem')
            .that_notifies('Service[kube-proxy]')
        end
      end

      context 'with token auth' do
        let(:params) do
          {
            auth: 'token',
            ca_cert: '/tmp/ca.pem',
            token: 'blah',
          }
        end

        it do
          is_expected.to contain_kubeconfig('/srv/kubernetes/kube-proxy.kubeconf')
            .with_ca_cert('/tmp/ca.pem')
            .with_token('blah')
            .that_notifies('Service[kube-proxy]')
        end
      end

      context 'with incluster auth' do
        let(:params) do
          {
            auth: 'incluster',
          }
        end

        it { is_expected.not_to contain_kubeconfig('/srv/kubernetes/kube-proxy.kubeconf') }
        it { is_expected.to contain_k8s__binary('kube-proxy').with_ensure('absent') }
        it do
          sysconf = '/etc/sysconfig'
          sysconf = '/etc/default' if os_facts['os']['family'] == 'Debian'

          is_expected.to contain_file(File.join(sysconf, 'kube-proxy')).with_ensure('absent')
        end
        it { is_expected.to contain_systemd__unit_file('kube-proxy.service').with_ensure('absent') }
        it { is_expected.to contain_service('kube-proxy').with_ensure('stopped').with_enable(false) }
      end
    end
  end
end
