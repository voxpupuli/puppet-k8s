# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::install::container_runtime' do
  let(:pre_condition) do
    <<~PUPPET
      class { 'k8s':
        manage_container_manager => false,
      }
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it { is_expected.to contain_package('k8s container manager') }
      it { is_expected.to contain_file('/usr/share/containers/').with(ensure: 'directory') }
      it { is_expected.to contain_file('/usr/share/containers/oci/').with(ensure: 'directory') }
      it { is_expected.to contain_file('/usr/share/containers/oci/hooks.d').with(ensure: 'directory') }

      context 'when ensure set and package_manager == crio' do
        let(:params) do
          {
            package_ensure: '1.32.0',
            container_manager: 'crio',
          }
        end

        it { is_expected.to contain_package('k8s container manager').with_ensure('1.32.0') }

        it { is_expected.to contain_file('/etc/crio').with(ensure: 'directory') }
        it { is_expected.to contain_file('/etc/crio/crio.conf.d').with(ensure: 'directory') }
        it { is_expected.to contain_file('/etc/cni/net.d/100-crio-bridge.conf').with(ensure: 'absent') }
        it { is_expected.to contain_file('K8s crio cgroup manager').with(path: '/etc/crio/crio.conf.d/10-systemd.conf') }

        it {
          is_expected.to contain_file('/usr/libexec/crio/conmon').with(
            ensure: 'link',
            replace: false,
            target: '/usr/bin/conmon'
          )
        }

        it { is_expected.not_to contain_package 'runc' } if os_facts.dig('os', 'family') == 'Debian'
        it {
          is_expected.to contain_file('/usr/libexec/crio').with(ensure: 'directory') if os_facts.dig('os', 'family') == 'Suse'
        }
      end

      context 'when ensure set and k8s version < 1.28 and package_manager == crio' do
        let(:params) do
          {
            package_ensure: '1.26.0',
            container_manager: 'crio',
          }
        end

        it { is_expected.to contain_package('k8s container manager').with_ensure('1.26.0') }

        if os_facts.dig('os', 'family') == 'Debian'
          it { is_expected.to contain_package 'runc' }
          it { is_expected.to contain_file('/usr/lib/cri-o-runc').with(ensure: 'directory') }
          it { is_expected.to contain_file('/usr/lib/cri-o-runc/sbin').with(ensure: 'directory') }

          it {
            is_expected.to contain_file('/usr/lib/cri-o-runc/sbin/runc').with(
              ensure: 'link',
              replace: false,
              target: '/usr/sbin/runc'
            )
          }
        end
      end

      context 'when ensure set and and package_manager == containerd' do
        let(:params) do
          {
            package_ensure: '1.32.0',
            container_manager: 'containerd',
          }
        end

        it { is_expected.to contain_package('k8s container manager').with_ensure('1.32.0') }

        if os_facts.dig('os', 'family') == 'Debian'
          it { is_expected.to contain_package 'runc' }

          it { is_expected.to contain_file('/etc/containerd').with(ensure: 'directory') }
          it { is_expected.to contain_file('/etc/containerd/config.toml') }
          it { is_expected.to contain_service('containerd').with(ensure: 'running') }
        end
      end
    end
  end
end
