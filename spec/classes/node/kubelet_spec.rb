# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::node::kubelet' do
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
      it { is_expected.to contain_kmod__load('overlay') }
      it { is_expected.to contain_kmod__load('br_netfilter') }
      it { is_expected.to contain_sysctl('net.bridge.bridge-nf-call-iptables').with_ensure('present').with_value('1') }
      it { is_expected.to contain_sysctl('net.bridge.bridge-nf-call-ip6tables').with_ensure('present').with_value('1') }
      it { is_expected.to contain_sysctl('net.ipv4.ip_forward').with_ensure('present').with_value('1') }
      it { is_expected.to contain_sysctl('net.ipv6.conf.all.forwarding').with_ensure('present').with_value('1') }
    end
  end
end
