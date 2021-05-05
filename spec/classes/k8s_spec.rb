# frozen_string_literal: true

require 'spec_helper'

describe 'k8s' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      [ 'node', 'server' ].each do |role|
        context "with role #{role}" do
          let(:params) do
            {
              role: role,
            }
          end

          it { is_expected.to compile }
        end
      end
    end
  end
end
