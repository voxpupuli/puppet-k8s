# frozen_string_literal: true

require 'spec_helper'

describe 'k8s' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      %w[node server].each do |role|
        context "with role #{role}" do
          let(:params) do
            {
              role: role,
            }
          end

          it { is_expected.to compile }
        end
      end

      context 'With dual-stack' do
        it { is_expected.to compile }

        %w[node server].each do |role|
          context "with role #{role}" do
            let(:params) do
              {
                cluster_cidr: [
                  '10.0.0.0/16',
                  'fc00:cafe:42:0::/64',
                ],
                service_cluster_cidr: [
                  '10.1.0.0/24',
                  'fc00:cafe:42:1::/64',
                ],
                role: role,
              }
            end

            it { is_expected.to compile }
          end
        end
      end
    end
  end
end
