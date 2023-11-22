# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::install::container_runtime' do
  let(:pre_condition) do
    <<~PUPPET
      class { 'k8s':
        manage_container_manager => false,
      }
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it { is_expected.to contain_package('k8s container manager') }

      context 'when ensure set' do
        let(:params) do
          {
            package_ensure: '1.26.0'
          }
        end

        it { is_expected.to contain_package('k8s container manager').with_ensure('1.26.0') }
      end
    end
  end
end
