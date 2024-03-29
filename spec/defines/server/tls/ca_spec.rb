# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::tls::ca' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      key: '/tmp/ca.key',
      cert: '/tmp/ca.pem',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_exec('Create namevar CA key').with(
          command: "openssl genrsa -out '/tmp/ca.key' 2048",
          unless: "openssl pkey -in '/tmp/ca.key' -text | grep '2048 bit'"
        )
      end

      it do
        is_expected.to contain_exec('Create namevar CA cert').with(
          command: %r{openssl req -x509 -new -nodes -key '/tmp/ca.key'\s+-days '10000' -out '/tmp/ca.pem' -subj '/CN=namevar'},
          unless: "openssl x509 -CA '/tmp/ca.pem' -CAkey '/tmp/ca.key' -in '/tmp/ca.pem' -noout -set_serial 00"
        ).that_subscribes_to('File[/tmp/ca.key]')
      end

      it do
        is_expected.to contain_file('/tmp/ca.key').with(
          ensure: 'present',
          owner: 'root',
          group: 'root',
          mode: '0600',
          replace: false
        )
      end

      it do
        is_expected.to contain_file('/tmp/ca.pem').with(
          ensure: 'present',
          owner: 'root',
          group: 'root',
          mode: '0644',
          replace: false
        )
      end
    end
  end
end
