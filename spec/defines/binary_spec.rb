# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::binary' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      version: '1.0',
    }
  end

  let(:pre_condition) do
    'include ::k8s'
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it { is_expected.to contain_file('/opt/k8s/1.0').with(ensure: 'directory') }

      %w[package tarball loose hyperkube].each do |method|
        context "using #{method} packaging" do
          %w[kubelet kube-apiserver kubectl].each do |binary|
            context "for binary #{binary}" do
              let(:title) { binary }
              let(:params) do
                {
                  ensure: 'present',
                  version: '1.0',
                  packaging: method,
                }
              end

              it { is_expected.to compile }

              it do
                is_expected.to contain_file("/opt/k8s/1.0/#{binary}").with(
                  ensure: 'present',
                  mode: '0755'
                )
              end

              it do
                is_expected.to contain_file("/usr/bin/#{binary}").with(
                  ensure: 'present',
                  mode: '0755'
                )
              end

              case method
              when 'loose'
                it do
                  is_expected.to contain_file("/opt/k8s/1.0/#{binary}").with(
                    ensure: 'present',
                    mode: '0755',
                    source: "https://storage.googleapis.com/kubernetes-release/release/v1.0/bin/linux/amd64/#{binary}"
                  )
                end
              when 'hyperkube'
                it do
                  is_expected.to contain_file('/opt/k8s/1.0/hyperkube').with(
                    ensure: 'present',
                    mode: '0755',
                    source: 'https://storage.googleapis.com/kubernetes-release/release/v1.0/bin/linux/amd64/hyperkube'
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end
