# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::scheduler' do
  let(:pre_condition) do
    <<~PUPPET
    function assert_private() {}

    include ::k8s
    class { '::k8s::server':
      manage_etcd => true,
      manage_certs => true,
      manage_components => false,
      manage_resources => false,
      node_on_server => false,
    }
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it { is_expected.to contain_kubeconfig('/srv/kubernetes/kube-scheduler.kubeconf') }
      it { is_expected.not_to contain_file('/etc/kubernetes/manifests/kube-scheduler.yaml') }
      it do
        is_expected.to contain_file('/etc/sysconfig/kube-scheduler')
          .with_content(
            <<~SYSCONF,
            ### NB: File managed by Puppet.
            ###     Any changes will be overwritten.
            #
            ## Kubernetes Scheduler configuration
            #

            KUBE_SCHEDULER_ARGS="--leader-elect=true --kubeconfig=/srv/kubernetes/kube-scheduler.kubeconf"
            SYSCONF
          ).that_notifies('Service[kube-scheduler]')
      end
      it { is_expected.to contain_systemd__unit_file('kube-scheduler.service').that_notifies('Service[kube-scheduler]') }
      it do
        is_expected.to contain_service('kube-scheduler').with(
          ensure: 'running',
          enable: true,
        )
      end
    end
  end
end
