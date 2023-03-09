# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::install::kubectl' do
  let(:pre_condition) do
    <<~PUPPET
      include k8s
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
