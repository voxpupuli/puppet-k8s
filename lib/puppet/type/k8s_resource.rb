# frozen_string_literal: true

Puppet::Type.newtype(:k8s_resource) do
  def validate_k8s_name(name)
    return if %r{^[a-z0-9-.]{0,253}$}.match? name

    raise Puppet::Error, 'Name must match Kubernetes requirements (only a-z, 0-9, -, and ., max 253 chars)'
  end

  desc <<-DOC
  Example:

  To encode the bootstrap token "tokenid.tokensecret" into a Kubernetes secret;

      $tokenid = 'tokenid'
      $tokensecret = 'tokensecret'
      k8s_resource { "bootstrap-token-${tokenid}":
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

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the resource'

    validate do |value|
      validate_k8s_name value
    end
  end

  newparam(:namespace) do
    desc 'The namespace the resource is contained in'

    validate do |value|
      validate_k8s_name value
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

  newparam(:api_version) do
    desc 'The apiVersion of the resource'
  end

  newparam(:kind) do
    desc 'The kind of the resource'
  end

  newparam(:content) do
    desc 'The resource content, will be used as the base for the resulting Kubernetes resource'
    validate do |value|
      unless value.is_a? Hash
        raise Puppet::Error, 'Content must be a valid content hash'
      end

      if ['apiVersion', 'kind'].any? { |key| value.key? key }
        raise Puppet::Error, "Can't specify apiVersion or kind in content"
      end
    end
  end

  autorequire(:file) do
    [
      self[:kubeconfig],
    ]
  end
end
