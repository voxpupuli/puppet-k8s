# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::install::fluxcd' do
  let(:pre_condition) do
    <<~PUPPET
      include k8s

      function extlib::version_latest_github(String[1] $pkg) {
        return 'v1.2.3'
      }
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      context "with ensure => present" do
        let(:params) do
          {
            ensure: 'present'
          }
        end

        it do
          is_expected.to contain_archive('FluxCD CLI')
                         .with_source('https://github.com/fluxcd/flux2/releases/download/v1.2.3/flux_1.2.3_linux_amd64.tar.gz')
                         .with_extract_command("tar -C /usr/local/bin -xf %s  flux")
                         .with_creates('/usr/local/bin/flux')
        end

        it do
          is_expected.to contain_file('/usr/local/bin/flux')
                         .with_ensure('file')
                         .with_mode('0755')
                         .that_requires('Archive[FluxCD CLI]')
        end
      end

      context "with ensure => latest" do
        let(:params) do
          {
            ensure: 'latest'
          }
        end

        it do
          is_expected.to contain_archive('FluxCD CLI')
                         .with_source('https://github.com/fluxcd/flux2/releases/download/v1.2.3/flux_1.2.3_linux_amd64.tar.gz')
                         .with_extract_command("tar -C /usr/local/bin -xf %s --transform='s/flux/flux-1.2.3/' flux")
                         .with_creates('/usr/local/bin/flux-1.2.3')
        end

        it do
          is_expected.to contain_file('/usr/local/bin/flux')
                         .with_ensure('link')
                         .with_target('/usr/local/bin/flux-1.2.3')
                         .that_requires('Archive[FluxCD CLI]')
        end
      end

      context "with install => true" do
        let(:params) do
          {
            install: true
          }
        end

        it do
          is_expected.to contain_exec('FluxCD install')
                         .with_command('flux install --export  | kubectl --kubeconfig /root/.kube/config apply --server-side --force-conflicts -f -')
                         .with_refreshonly(true)
                         .that_requires('File[/usr/local/bin/flux]')
        end
      end
    end
  end
end
