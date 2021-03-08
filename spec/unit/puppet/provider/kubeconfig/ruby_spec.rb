require 'spec_helper'

ruby_provider = Puppet::Type.type(:kubeconfig).provider(:ruby)

RSpec.describe ruby_provider do
  it_behaves_like 'a kubeconfig provider', ruby_provider

  describe 'ruby provider' do
    include PuppetlabsSpec::Files
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
            'user' => {
            },
          },
        ],
        'current-context' => '',
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

      before(:each) do
        File.write(catmpfile, 'ca.crt')
      end

      it 'creates default config, updates components' do
        provider.create

        expect(Psych.load(File.read(tmpfile))).to eq resulting_kubeconfig
      end
    end

    context 'when applied' do
      it 'applies correctly' do
        allow(Puppet::Util::Storage).to receive(:store)
        expect(File.exists?(name)).to eq(false)

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(resource)
        catalog.apply

        expect(Psych.load(File.read(tmpfile))).to eq default_kubeconfig
      end

      it 'updates correctly' do
        allow(Puppet::Util::Storage).to receive(:store)
        expect(File.exists?(name)).to eq(false)

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(resource)
        catalog.apply

        expect(Psych.load(File.read(tmpfile))).to eq default_kubeconfig
      end
    end
  end
end
