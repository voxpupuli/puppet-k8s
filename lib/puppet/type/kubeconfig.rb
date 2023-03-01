# frozen_string_literal: true

Puppet::Type.newtype(:kubeconfig) do
  desc <<-DOC
  Example:

      kubeconfig { '/var/lib/kubernetes/utility.conf':
        ca_cert => '/etc/kubernetes.ca.pem',
        token   => 'utility-token',
      }
  DOC

  ensurable do
    desc 'Whether the kubeconfig should be present or absent (default: present)'

    newvalue(:present) do
      provider.create unless provider.exists?
    end

    newvalue(:absent) do
      provider.destroy
    end

    defaultto(:present)

    def change_to_s(currentvalue, newvalue)
      if currentvalue == :absent || currentvalue.nil?
        if provider.exists? && !provider.valid?
          'updated'
        else
          'created'
        end
      elsif newvalue == :absent
        'removed'
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

  newparam(:path, namevar: true) do
    desc 'An arbitrary path used as the identity of the resource.'

    validate do |value|
      raise Puppet::Error, "File paths must be fully qualified, not '#{value}'" unless Puppet::Util.absolute_path?(value)
    end
  end

  newparam(:owner) do
    desc 'The owner of the kubeconfig file'
  end
  newparam(:group) do
    desc 'The owner of the kubeconfig file'
  end

  newparam(:cluster) do
    desc 'The name of the cluster to manage in the kubeconfig file'
    defaultto 'default'
  end
  newparam(:context) do
    desc 'The name of the cluster to manage in the kubeconfig file'
    defaultto 'default'
  end
  newparam(:user) do
    desc 'The name of the user to manage in the kubeconfig file'
    defaultto 'default'
  end
  newparam(:namespace) do
    desc 'The namespace to default to'
    defaultto 'default'
  end
  newparam(:current_context) do
    desc 'The current context to set'
  end

  newparam(:server) do
    desc 'The server URL for the cluster'
  end

  newparam(:skip_tls_verify) do
    desc 'Skip verifying the TLS certs for the cluster'
    newvalues(true, false)
    defaultto false
  end
  newparam(:tls_server_name) do
    desc 'Specify an alternate server name to use for TLS verification'
  end

  newparam(:embed_certs) do
    desc 'Should the certificate files be embedded into the kubeconfig file'
    newvalues(true, false)
    defaultto true
  end

  newparam(:ca_cert) do
    desc 'The path to a CA certificate to include in the kubeconfig'

    validate do |value|
      raise Puppet::Error, "File paths must be fully qualified, not '#{value}'" unless Puppet::Util.absolute_path?(value)
    end
  end
  newparam(:client_cert) do
    desc 'The path to a client certificate to include in the kubeconfig'

    validate do |value|
      raise Puppet::Error, "File paths must be fully qualified, not '#{value}'" unless Puppet::Util.absolute_path?(value)
    end
  end
  newparam(:client_key) do
    desc 'The path to a client key to include in the kubeconfig'

    validate do |value|
      raise Puppet::Error, "File paths must be fully qualified, not '#{value}'" unless Puppet::Util.absolute_path?(value)
    end
  end

  newparam(:token) do
    desc 'An authentication token for a user'
  end

  newparam(:token_file) do
    desc 'The path to a file containing an authentication token'

    validate do |value|
      raise Puppet::Error, "File paths must be fully qualified, not '#{value}'" unless Puppet::Util.absolute_path?(value)
    end
  end

  newparam(:username) do
    desc 'The username of a user'
  end
  newparam(:password) do
    desc 'The password of a user'
  end

  validate do
    raise Puppet::Error, "Can't specify both token and token_file for the same kubeconfig entry" if self[:token] && self[:token_file]
    raise(Puppet::Error, 'path is a required attribute') unless self[:path]
  end

  # Ensure the file or directory exists
  autorequire(:file) do
    req = [
      self[:path],
      Pathname.new(self[:path]).parent.to_s,
    ]
    if self[:embed_certs]
      req += [
        self[:ca_cert],
        self[:client_cert],
        self[:client_key],
      ].compact
    end
    req += [self[:token_file]].compact

    req
  end
end
