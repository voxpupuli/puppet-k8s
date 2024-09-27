# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::node' do
  let(:pre_condition) do
    <<~PUPPET
      include ::k8s
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      if os_facts.dig('os', 'family') == 'Debian'
        it { is_expected.to contain_package 'conntrack' }
      else
        it { is_expected.to contain_package 'conntrack-tools' }
      end
    end
  end
end
