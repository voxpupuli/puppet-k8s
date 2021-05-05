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
  end
end
