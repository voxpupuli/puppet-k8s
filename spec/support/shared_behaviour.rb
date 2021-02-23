require 'spec_helper'
require 'tmpdir'

RSpec.shared_examples 'a kubeconfig provider' do |provider_class|
  describe provider_class do
    let(:resource) do
      Puppet::Type::Kubeconfig.new(title: 'test', path: '/tmp/kubeconfig', server: 'https://kubernetes.home.lan:6443')
    end

    let(:provider) do
      provider_class.new(resource)
    end
  end
end
