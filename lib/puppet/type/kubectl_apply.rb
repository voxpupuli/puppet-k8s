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
    newvalue(:present) do
      provider.create unless provider.exists?
    end

    newvalue(:absent) do
      provider.destroy if provider.exists?
    end

    defaultto(:present)

    def change_to_s(currentvalue, newvalue)
      if currentvalue == :absent || currentvalue.nil?
        if provider.resource_diff
          if resource[:show_diff]
            "update #{resource[:kind]} #{resource.nice_name} with #{provider.resource_diff.inspect}"
          else
            "update #{resource[:kind]} #{resource.nice_name}"
          end
        else
          "create #{resource[:kind]} #{resource.nice_name}"
        end
      elsif newvalue == :absent
        "remove #{resource[:kind]} #{resource.nice_name}"
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

  newparam(:name) do
    desc 'The name of the resource'

    validate do |value|
      unless value.match? %r{^[a-z0-9.-]{0,253}$}
        raise Puppet::Error, 'Name must be valid'
      end
    end
  end

  newparam(:namespace) do
    desc 'The namespace the resource is contained in'

    validate do |value|
      unless value.match? %r{^[a-z0-9.-]{0,253}$}
        raise Puppet::Error, 'Namespace must be valid'
      end
    end
  end

  newparam(:kubeconfig) do
    desc 'The kubeconfig file to use for handling the resource'

    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        raise Puppet::Error, 'Kubeconfig path must be fully qualified'
      end
    end
  end
  newparam(:file) do
    desc 'The local file for the resource'

    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        raise Puppet::Error, 'File path must be fully qualified'
      end
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

  newparam(:show_diff, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Whether to display the difference when the resource changes'
    defaultto(:true)
  end

  newparam(:content) do
    desc 'The resource content, will be used as the base for the resulting Kubernetes resource'
    defaultto({})

    validate do |value|
      unless value.is_a? Hash
        raise Puppet::Error, 'Content must be a valid content hash'
      end

      if ['apiVersion', 'kind'].any? { |key| value.key? key }
        raise Puppet::Error, "Can't specify apiVersion or kind in content"
      end
    end
  end

  validate do
    raise Puppet::Error, 'API version is required' unless self[:api_version]
    raise Puppet::Error, 'Kind is required' unless self[:kind]
  end

  autorequire(:kubeconfig) do
    [ self[:kubeconfig] ]
  end
  autorequire(:file) do
    [
      self[:kubeconfig],
      self[:file],
    ]
  end
  autorequire(:k8s__binary) do
    [ 'kubectl' ]
  end

  def nice_name
    return self[:name] unless self[:namespace]

    "#{self[:namespace]}/#{self[:name]}"
  end
end
