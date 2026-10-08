# frozen_string_literal: true

require 'spec_helper'

ruby_provider = Puppet::Type.type(:kubeconfig).provider(:ruby)

RSpec.describe ruby_provider do
  it_behaves_like 'a kubeconfig provider', ruby_provider

  describe 'ruby provider' do
    let(:tmpfile) do
      tmpfilename('kubeconfig_test')
    end

    let(:name) { tmpfile }
    let(:resource_properties) do
      {
        name: name,
        server: 'https://kubernetes.home.lan:6443',
      }
    end
    let(:default_kubeconfig) do
      {
        'apiVersion' => 'v1',
        'clusters' => [
          {
            'name' => 'default',
            'cluster' => {
              'server' => 'https://kubernetes.home.lan:6443',
            },
          },
        ],
        'contexts' => [
          {
            'name' => 'default',
            'context' => {
              'cluster' => 'default',
              'namespace' => 'default',
              'user' => 'default',
            },
          },
        ],
        'users' => [
          {
            'name' => 'default',
            'user' => {},
          },
        ],
        'current-context' => 'default',
        'kind' => 'Config',
        'preferences' => {},
      }
    end
    let(:resource) { Puppet::Type::Kubeconfig.new(resource_properties) }
    let(:provider) { ruby_provider.new(resource) }

    before do
      resource.provider = provider
    end

    context 'no extra properties specified' do
      it 'creates default config, updates components' do
        provider.create

        stat = File.stat(tmpfile)
        expect(stat.mode & 0o777).to eq 0o600

        expect(Psych.load(File.read(tmpfile))).to eq default_kubeconfig
      end
    end

    context 'ca certificate provided' do
      let :catmpfile do
        tmpfilename('kubeconfig_ca.crt_test')
      end
      let(:resource_properties) do
        {
          name: name,
          server: 'https://kubernetes.home.lan:6443',
          ca_cert: catmpfile,
        }
      end
      let(:resulting_kubeconfig) do
        conf = default_kubeconfig.dup
        conf['clusters'][0]['cluster']['certificate-authority-data'] = 'Y2EuY3J0'
        conf
      end

      before do
        File.write(catmpfile, 'ca.crt')
      end

      it 'creates default config, updates components' do
        provider.create

        expect(Psych.load(File.read(tmpfile))).to eq resulting_kubeconfig
      end
    end

    context 'switching between embedded and referenced certificates' do
      let(:catmpfile) { tmpfilename('kubeconfig_ca.crt_test') }
      let(:certtmpfile) { tmpfilename('kubeconfig_client.crt_test') }
      let(:keytmpfile) { tmpfilename('kubeconfig_client.key_test') }
      let(:resource_properties) do
        {
          name: name,
          server: 'https://kubernetes.home.lan:6443',
          ca_cert: catmpfile,
          client_cert: certtmpfile,
          client_key: keytmpfile,
          embed_certs: embed_certs,
        }
      end

      before do
        File.write(catmpfile, 'ca.crt')
        File.write(certtmpfile, 'client.crt')
        File.write(keytmpfile, 'client.key')

        previous = Puppet::Type::Kubeconfig.new(resource_properties.merge(embed_certs: !embed_certs))
        previous.provider = ruby_provider.new(previous)
        previous.provider.create
      end

      context 'from embedded data to file paths' do
        let(:embed_certs) { false }

        it 'drops the inline data and references the files' do
          expect(provider.exists?).to be false
          provider.create

          conf = Psych.load(File.read(tmpfile))
          expect(conf['clusters'][0]['cluster']).to eq(
            'server' => 'https://kubernetes.home.lan:6443',
            'certificate-authority' => catmpfile,
          )
          expect(conf['users'][0]['user']).to eq(
            'client-certificate' => certtmpfile,
            'client-key' => keytmpfile,
          )
          expect(ruby_provider.new(resource).exists?).to be true
        end
      end

      context 'from file paths to embedded data' do
        let(:embed_certs) { true }

        it 'drops the paths and embeds the file contents' do
          expect(provider.exists?).to be false
          provider.create

          conf = Psych.load(File.read(tmpfile))
          expect(conf['clusters'][0]['cluster']).to eq(
            'server' => 'https://kubernetes.home.lan:6443',
            'certificate-authority-data' => 'Y2EuY3J0',
          )
          expect(conf['users'][0]['user']).to eq(
            'client-certificate-data' => Base64.strict_encode64('client.crt'),
            'client-key-data' => Base64.strict_encode64('client.key'),
          )
          expect(ruby_provider.new(resource).exists?).to be true
        end
      end
    end

    context 'when applied' do
      it 'applies correctly' do
        allow(Puppet::Util::Storage).to receive(:store)

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(resource)
        catalog.apply

        expect(Psych.load(File.read(tmpfile))).to eq default_kubeconfig
      end
    end
  end
end
