# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server' do
  let(:pre_condition) do
    <<~PUPPET
      include k8s
    PUPPET
  end

  let(:params) do
    {
      node_on_server: false,
      etcd_servers: ['https://localhost:2379']
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
