# frozen_string_literal: true

Puppet::Type.newtype(:kubectl_apply) do
  desc <<-DOC
  Example:

  To encode the bootstrap token "tokenid.tokensecret" into a Kubernetes secret;

      $tokenid = 'tokenid'
      $tokensecret = 'tokensecret'
      kubectl_apply { "bootstrap-token-${tokenid}":
        namespace   => 'kube-system',
        kubeconfig  => '/root/.kube/config',

        api_version => 'v1,
        kind        => 'Secret',

        content     => {
          type => 'bootstrap.kubernetes.io/token',
          data => {
            'token-id'                       => Binary.new($tokenid, '%s'),
            'token-secret'                   => Binary.new($tokensecret, '%s'),
            'usage-bootstrap-authentication' => 'true',
          },
        },
      }
  DOC

  ensurable do
    desc 'Whether the described resource should be present or absent (default: present)'

    newvalue(:present) do
      provider.create unless provider.exists?
    end

    newvalue(:absent) do
      provider.destroy if provider.exists?
    end

    defaultto(:present)

    def change_to_s(currentvalue, newvalue)
      if currentvalue == :absent || currentvalue.nil?
        if provider.exists_in_cluster
          if resource[:show_diff] && provider.resource_diff
            "updated #{resource[:kind]} #{resource.nice_name} with #{provider.resource_diff.inspect}"
          else
            "updated #{resource[:kind]} #{resource.nice_name}"
          end
        elsif resource[:show_diff] && provider.resource_diff
          "created #{resource[:kind]} #{resource.nice_name} with #{provider.resource_diff.inspect}"
        else
          "created #{resource[:kind]} #{resource.nice_name}"
        end
      elsif newvalue == :absent
        "removed #{resource[:kind]} #{resource.nice_name}"
      else
        super
      end
    end

    def retrieve
      prov = @resource.provider
      raise Puppet::Error, 'Could not find provider' unless prov

      prov.exists? ? :present : :absent
    end
  end

  # XXX Better way to separate name from Puppet namevar handling?
  newparam(:resource_name) do
    desc 'The name of the resource'

    validate do |value|
      raise Puppet::Error, 'Resource name must be valid' unless value.match? %r{^([a-z0-9][a-z0-9.:-]{0,251}[a-z0-9]|[a-z0-9])$}
    end
  end

  newparam(:name, namevar: true) do
    desc 'The Puppet name of the instance'
  end

  newparam(:namespace) do
    desc 'The namespace the resource is contained in'

    validate do |value|
      raise Puppet::Error, 'Namespace must be valid' unless value.match? %r{^[a-z0-9.-]{0,253}$}
    end
  end

  newparam(:kubeconfig) do
    desc 'The kubeconfig file to use for handling the resource'

    validate do |value|
      raise Puppet::Error, 'Kubeconfig path must be fully qualified' unless Puppet::Util.absolute_path?(value)
    end
  end
  newparam(:file) do
    desc 'The local file for the resource'

    validate do |value|
      raise Puppet::Error, 'File path must be fully qualified' unless Puppet::Util.absolute_path?(value)
    end
  end

  newparam(:api_version) do
    desc 'The apiVersion of the resource'
  end

  newparam(:kind) do
    desc 'The kind of the resource'
  end

  newparam(:update, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Whether to update the resource if the content differs'
    defaultto(:true)
  end

  newparam(:recreate, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Should updates be done by removal and recreation'
    defaultto(:false)
  end

  newparam(:show_diff, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Whether to display the difference when the resource changes'
    defaultto(:false)
  end

  newparam(:content) do
    desc 'The resource content, will be used as the base for the resulting Kubernetes resource'
    defaultto({})

    validate do |value|
      raise Puppet::Error, 'Content must be a valid content hash' unless value.is_a? Hash

      raise Puppet::Error, "Can't specify apiVersion or kind in content" if %w[apiVersion kind].any? { |key| value.key? key }
    end
  end

  validate do
    self[:resource_name] = self[:name] if self[:resource_name].nil?

    raise Puppet::Error, 'API version is required' unless self[:api_version]
    raise Puppet::Error, 'Kind is required' unless self[:kind]
  end

  autorequire(:kubeconfig) do
    [self[:kubeconfig]]
  end
  autorequire(:service) do
    ['kube-apiserver']
  end
  autorequire(:exec) do
    ['k8s-apiserver wait online']
  end
  autorequire(:file) do
    [
      self[:kubeconfig],
      self[:file],
    ]
  end
  autorequire(:k8s__binary) do
    ['kubectl']
  end

  def nice_name
    return self[:name] unless self[:namespace]

    "#{self[:namespace]}/#{self[:name]}"
  end
end
