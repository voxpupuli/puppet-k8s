require 'spec_helper'
require 'puppet'

describe Puppet::Type.type(:kubeconfig) do
  let(:resource) do
    Puppet::Type.type(:kubeconfig).new(
      path: '/tmp/kubeconfig',
      server: 'https://kubernetes.home.lan:6443'
    )
  end

  context 'resource defaults' do
    it { expect(resource[:path]).to eq '/tmp/kubeconfig' }
    it { expect(resource[:name]).to eq '/tmp/kubeconfig' }
    it { expect(resource[:cluster]).to eq 'default' }
    it { expect(resource[:context]).to eq 'default' }
    it { expect(resource[:user]).to eq 'default' }
    it { expect(resource[:namespace]).to eq 'default' }
    it { expect(resource[:skip_tls_verify]).to_not eq :true }
    it { expect(resource[:embed_certs]).to eq :true }
  end

  it 'verify resource[:path] is absolute filepath' do
    expect do
      resource[:path] = 'relative/file'
    end.to raise_error(Puppet::Error, %r{File paths must be fully qualified, not 'relative/file'})
  end

  it 'verify resource[:ca_cert] is absolute filepath' do
    expect do
      resource[:ca_cert] = 'relative/file'
    end.to raise_error(Puppet::Error, %r{File paths must be fully qualified, not 'relative/file'})
  end

  it 'verify resource[:client_cert] is absolute filepath' do
    expect do
      resource[:client_cert] = 'relative/file'
    end.to raise_error(Puppet::Error, %r{File paths must be fully qualified, not 'relative/file'})
  end

  it 'verify resource[:client_key] is absolute filepath' do
    expect do
      resource[:client_key] = 'relative/file'
    end.to raise_error(Puppet::Error, %r{File paths must be fully qualified, not 'relative/file'})
  end

  it 'verify resource[:token_file] is absolute filepath' do
    expect do
      resource[:token_file] = 'relative/file'
    end.to raise_error(Puppet::Error, %r{File paths must be fully qualified, not 'relative/file'})
  end

  describe 'archive autorequire' do
    let(:file_resource) { Puppet::Type.type(:file).new(name: '/tmp') }
    let(:kubeconfig_resource) do
      described_class.new(
        path: '/tmp/kubeconfig',
        server: 'https://kubernetes.home.lan:6443'
      )
    end

    let(:auto_req) do
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file_resource
      catalog.add_resource kubeconfig_resource

      kubeconfig_resource.autorequire
    end

    it 'creates relationship' do
      expect(auto_req.size).to be 1
    end
    it 'links to archive resource' do
      expect(auto_req[0].target).to eql kubeconfig_resource
    end
    it 'autorequires parent directory' do
      expect(auto_req[0].source).to eql file_resource
    end
  end
end
