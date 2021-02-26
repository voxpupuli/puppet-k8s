require 'spec_helper'
require 'tmpdir'

RSpec.shared_examples 'a kubeconfig provider' do |provider_class|
  describe provider_class do
    include PuppetlabsSpec::Files
    let(:tmpfile) do
      tmpfilename('kubeconfig_test')
    end
    let(:resource_properties) do
      {
        title: 'test',
        path: tmpfile,
        server: 'https://kubernetes.home.lan:6443',
      }
    end
    let(:resource) do
      Puppet::Type::Kubeconfig.new(resource_properties)
    end

    let(:provider) do
      provider_class.new(resource)
    end

    context 'with sample config file' do
      let(:sample_config) do
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
          'current-context' => 'default',
          'kind' => 'Config',
          'preferences' => {},
        }
      end

      before(:each) do
        File.write(tmpfile, Psych.dump(sample_config))
      end

      it 'detects existing entries' do
        expect(provider.exists?).to eq true
      end

      it 'detects changes' do
        provider.kubeconfig_content['apiVersion'] = 'v2'
        expect(provider.changed?).to eq true
      end

      it 'detects faulty clusters' do
        provider.kubeconfig_content['clusters'][0]['cluster']['server'] = 'http://example.com'
        expect(provider.exists?).to eq false
      end

      it 'detects missing clusters' do
        provider.kubeconfig_content['clusters'].clear
        expect(provider.exists?).to eq false
      end

      it 'detects missing contexts' do
        provider.kubeconfig_content['contexts'].clear
        expect(provider.exists?).to eq false
      end

      it 'detects faulty contexts' do
        provider.kubeconfig_content['contexts'][0]['context']['cluster'] = 'example'
        expect(provider.exists?).to eq false
      end

      it 'detects missing users' do
        provider.kubeconfig_content['users'].clear
        expect(provider.exists?).to eq false
      end

      it 'detects faulty users' do
        provider.kubeconfig_content['users'][0]['user']['token'] = 'example'
        expect(provider.exists?).to eq false
      end
    end
  end
end
