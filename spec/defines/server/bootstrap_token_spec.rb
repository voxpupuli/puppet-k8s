# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::bootstrap_token' do
  let(:title) { 'nameva' }
  let(:params) do
    {
      kubeconfig: '/root/.kube/config',
      secret: sensitive('some0secret0valu')
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_kubectl_apply('bootstrap-token-nameva').with(
          ensure: 'present',
          kubeconfig: '/root/.kube/config',
          namespace: 'kube-system',
          api_version: 'v1',
          kind: 'Secret',
          content: {
            'type' => 'bootstrap.kubernetes.io/token',
            'data' => {
              'token-id' => 'bmFtZXZh', # 'nameva'
              'token-secret' => 'c29tZTBzZWNyZXQwdmFsdQ==', # 'some0secret0valu'
              'usage-bootstrap-authentication' => 'dHJ1ZQ==', # true
            }
          }
        )
      end

      describe 'with invalid secret' do
        let(:params) do
          {
            kubeconfig: '/root/.kube/config',
            secret: sensitive('Something not supported by Kubernetes')
          }
        end

        it { is_expected.not_to compile }
      end
    end
  end
end
