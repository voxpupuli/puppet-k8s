# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::repo' do
  let(:pre_condition) do
    <<~PUPPET
      class { '::k8s':
        manage_repo => false,
      }
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
    context 'on RedHat/CentOS 7, 8 and 9' do
      let(:facts) { os_facts }
      if os['family'] == 'RedHat' and os['release']['major'] == '7'
        it { is_expected.to contain_yumrepo('libcontainers:stable').with_baseurl => 'https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_7/'}
      end
      if os['family'] == 'RedHat' and os['release']['major'] == '8'
        it { is_expected.to contain_yumrepo('libcontainers:stable').with_baseurl => 'https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_8_Stream/'}
      end
      if os['family'] == 'RedHat' and os['release']['major'] == '9'
        it { is_expected.to contain_yumrepo('libcontainers:stable').with_baseurl => 'https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_9_Stream/'}
      end
    end
  end
end
