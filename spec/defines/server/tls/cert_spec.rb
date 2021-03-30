# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::server::tls::cert' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      cert_path: '/tmp/certs',
      ca_key: '/tmp/ca.key',
      ca_cert: '/tmp/ca.pem',

      distinguished_name: {
        commonName: 'test-cert'
      },
      addn_names: [
        '172.31.0.0',
        'example.com',
        '2001::19'
      ]
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_file('/tmp/certs/namevar.cnf').with(
          content: <<~CNF
          [req]
          distinguished_name = req_distinguished_name
          req_extensions     = v3_req
          prompt             = no

          [req_distinguished_name]
          commonName = test-cert

          [v3_req]
          basicConstraints = CA:FALSE
          keyUsage         = nonRepudiation, digitalSignature, keyEncipherment
          extendedKeyUsage = clientAuth
          subjectAltName   = @alt_names

          [alt_names]
          DNS.1 = example.com
          IP.1 = 172.31.0.0
          IP.2 = 2001::19
          CNF
        )
      end
      it do
        is_expected.to contain_exec('Create K8s namevar key').with(
          path: ['/usr/bin'],
          command: "openssl genrsa -out '/tmp/certs/namevar.key' 2048",
          creates: '/tmp/certs/namevar.key'
        )
      end
      it do
        is_expected.to contain_exec('Create K8s namevar CSR').with(
          path: ['/usr/bin'],
          command: %r{openssl req -new -key '/tmp/certs/namevar\.key' \s+ -out '/tmp/certs/namevar\.key' -config '/tmp/certs/namevar\.cnf'},
          creates: '/tmp/certs/namevar.key'
        )
      end
      it do
        is_expected.to contain_exec('Sign K8s namevar cert').with(
          path: ['/usr/bin'],
          command: %r{openssl x509 -req -in '/tmp/certs/namevar\.key' \s+ -CA '/tmp/ca.pem' -CAkey '/tmp/ca\.key' -CAcreateserial \s+ -out '/tmp/certs/namevar\.pem' -days '10000' \s+ -extensions v3_req -extfile '/tmp/certs/namevar\.cnf'},
          creates: '/tmp/certs/namevar.pem'
        )
      end

      it do
        is_expected.to contain_file('/tmp/certs/namevar.key').with(
          ensure: 'present',
          owner: 'root',
          group: 'root',
          mode: '0600',
          replace: false
        )
      end
      it do
        is_expected.to contain_file('/tmp/certs/namevar.pem').with(
          ensure: 'present',
          owner: 'root',
          group: 'root',
          mode: '0640',
          replace: false
        )
      end
    end
  end
end
