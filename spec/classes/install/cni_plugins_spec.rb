# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::install::cni_plugins' do
  let(:pre_condition) do
    <<~PUPPET
      include k8s
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it { is_expected.to contain_file('/opt/cni') }

      context 'when method is tarball' do
        let(:params) do
          {
            method: 'tarball',
            version: 'v1.0.0'
          }
        end

        it { is_expected.to contain_archive('cni-plugins').with_extract_path('/opt/k8s/cni-v1.0.0') }

        context 'without storage fact' do
          it { is_expected.not_to contain_exec('Retain custom CNI binaries') }
        end

        context 'with storage fact' do
          let(:facts) { os_facts.merge(cni_plugins_version: 'v0.0.0') }

          it { is_expected.to contain_exec('Retain custom CNI binaries') }
        end
      end
    end
  end
end
