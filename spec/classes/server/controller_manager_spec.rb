# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::controller_manager' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
