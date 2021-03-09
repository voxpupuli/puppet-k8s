require 'spec_helper'
require 'puppet'

describe Puppet::Type.type(:k8s_resource) do
  let(:resource) do
    Puppet::Type.type(:k8s_resource).new(
      name: 'bootstrap-token-example',
      namespace: 'kube-system',

      api_version: 'v1',
      kind: 'Secret',

      content: {
        'token-id': 'id',
        'token-secret': 'secret',
        'usage-bootstrap-authentication': 'true',
      }
    )
  end

  context 'resource defaults' do
    it { expect(resource[:kubeconfig]).to eq nil }
    it { expect(resource[:update]).to eq true }
  end

  [
    'simplename',
    'default-token-6mqpl',
    'metrics-server-7cb45bbfd5-gz4t6',
  ].each do |name|
    it 'accepts valid names' do
      expect { resource[:name] = name }.not_to raise_error
    end
  end

  [
    'CamelCasedName',
    'name-with space',
    'snake_cased_name',
    'fqdn.like/name',
  ].each do |name|
    it 'rejects invalid names' do
      expect { resource[:name] = name }.to raise_error(Puppet::Error, %r{Name must be valid})
    end
  end

  [
    'default',
    'kube-system',
    'some-ridiculously-long-name-thats-still-inside-of-the-limitations-kubernetes-has',
  ].each do |name|
    it 'accepts valid namespaces' do
      expect { resource[:namespace] = name }.not_to raise_error
    end
  end

  [
    'CamelCasedName',
    'name-with space',
    'snake_cased_name',
    'fqdn.like/name',
  ].each do |name|
    it 'rejects invalid namespaces' do
      expect { resource[:namespace] = name }.to raise_error(Puppet::Error, %r{Namespace must be valid})
    end
  end

  it 'rejects too long namespaces' do
    expect { resource[:namespace] = 'x' * 254 }.to raise_error(Puppet::Error, %r{Namespace must be valid})
  end

  it 'verify resource[:kubeconfig] is absolute filepath' do
    expect { resource[:kubeconfig] = 'relative/file' }.to raise_error(Puppet::Error, %r{Kubeconfig path must be fully qualified})
  end

  it 'verify resource[:content] is a hash' do
    expect { resource[:content] = [] }.to raise_error(Puppet::Error, %r{Content must be a valid content hash})
  end

  it 'verify resource[:content] is safe' do
    expect { resource[:content] = { 'apiVersion' => 'v2' } }.to raise_error(Puppet::Error, %r{Can't specify apiVersion or kind in content})
    expect { resource[:content] = { 'kind' => 'something' } }.to raise_error(Puppet::Error, %r{Can't specify apiVersion or kind in content})
  end

  describe 'file autorequire' do
    let(:file_resource) { Puppet::Type.type(:file).new(name: '/root/.kube/config') }
    let(:k8s_resource) do
      described_class.new(
        name: 'blah',
        namespace: 'default',
        api_version: 'v1',
        kind: 'ConfigMap',
        kubeconfig: '/root/.kube/config',
      )
    end

    let(:auto_req) do
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file_resource
      catalog.add_resource k8s_resource

      k8s_resource.autorequire
    end

    it 'creates relationship' do
      expect(auto_req.size).to be 1
    end
    it 'links to file resource' do
      expect(auto_req[0].target).to eql k8s_resource
    end
  end
end
