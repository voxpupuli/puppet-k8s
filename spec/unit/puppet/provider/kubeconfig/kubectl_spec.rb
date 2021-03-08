require 'spec_helper'
require 'mkmf'

# To remove mkmf log files;
module MakeMakefile::Logging
  def self::open
    yield
  end
  def self::postpone
    yield File.open('/dev/null', 'wb')
  end
  def self::message(*_); end
end

kubectl_provider = Puppet::Type.type(:kubeconfig).provider(:kubectl)

RSpec.describe kubectl_provider do
  it_behaves_like 'a kubeconfig provider', kubectl_provider

  describe 'kubectl provider' do
    include PuppetlabsSpec::Files
    let(:tmpfile) do
      tmpfilename('kubeconfig_test')
    end

    let(:name) { tmpfile }
    let(:resource_properties) do
      {
        name: name,
        server: 'https://kubernetes.home.lan:6443',

        current_context: 'default',
      }
    end
    let(:resource) { Puppet::Type::Kubeconfig.new(resource_properties) }
    let(:provider) { kubectl_provider.new(resource) }

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

    before do
      resource.provider = provider
    end

    context 'without a local kubectl binary' do
      it 'creates default config, updates components' do
        expect(provider).to receive(:kubectl).with(*[
          '--kubeconfig',
          resource[:path],
          'config',
          'set-cluster',
          resource[:cluster],
          "--server=#{resource[:server]}",
        ])
        expect(provider).to receive(:kubectl).with(*[
          '--kubeconfig',
          resource[:path],
          'config',
          'set-context',
          resource[:context],
          "--cluster=#{resource[:cluster]}",
          "--user=#{resource[:user]}",
          "--namespace=#{resource[:namespace]}",
        ])
        expect(provider).to receive(:kubectl).with(*[
          '--kubeconfig',
          resource[:path],
          'config',
          'set-credentials',
          resource[:user],
        ])
        expect(provider).to receive(:kubectl).with(*[
          '--kubeconfig',
          resource[:path],
          'config',
          'use-context',
          resource[:current_context],
        ])
        expect(FileUtils).to receive(:chown).with(resource[:owner], resource[:group], resource[:path])

        provider.create
      end
    end

    context 'when applied with kubectl binary', if: find_executable('kubectl') do
      it 'applies correctly with minimal config' do
        allow(Puppet::Util::Storage).to receive(:store)

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(resource)
        catalog.apply

        data = Psych.load(File.read(tmpfile))
        expect(data).to eq default_kubeconfig
      end
    end
  end
end
