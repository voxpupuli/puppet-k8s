# frozen_string_literal: true

# Uses kubectl to handle kubeconfig entries
Puppet::Type.type(:kubeconfig).provide(:kubectl, parent: :ruby) do
  commands kubectl: 'kubectl'

  def update_cluster
    params = []
    params << "--embed-certs=#{resource[:embed_certs]}" if resource[:embed_certs] && resource[:ca_cert]
    params << "--server=#{resource[:server]}" if resource[:server]
    params << "--certificate-authority=#{resource[:ca_cert]}" if resource[:ca_cert]
    params << "--insecure-skip-tls-verify=#{resource[:skip_tls_verify]}" if resource[:skip_tls_verify]
    params << "--tls-server-name=#{resource[:tls_server_name]}" if resource[:tls_server_name]

    kubectl_call(
      'config', 'set-cluster',
      resource[:cluster],
      *params
    )
  end

  def update_context
    params = []
    params << "--cluster=#{resource[:cluster]}"
    params << "--user=#{resource[:user]}"
    params << "--namespace=#{resource[:namespace]}"

    kubectl_call(
      'config', 'set-context',
      resource[:context],
      *params
    )
  end

  def update_credentials
    params = []
    embed = resource[:embed_certs] && (resource[:client_cert] || resource[:client_key])
    params << "--embed-certs=#{resource[:embed_certs]}" if embed
    params << "--client-certificate=#{resource[:client_cert]}" if resource[:client_cert]
    params << "--client-key=#{resource[:client_key]}" if resource[:client_key]
    params << "--token=#{resource[:token]}" if resource[:token]
    params << "--token=#{File.read(resource[:token_file]).strip}" if resource[:token_file]
    params << "--username=#{resource[:username]}" if resource[:username]
    params << "--password=#{resource[:password]}" if resource[:password]

    kubectl_call(
      'config', 'set-credentials',
      resource[:context],
      *params
    )
  end

  def update_current_context
    kubectl_call(
      'config', 'use-context',
      resource[:current_context]
    )
  end

  def save; end

  def kubectl_call(*args)
    params = [
      '--kubeconfig',
      resource[:path],
    ]
    kubectl(*params, *args)
  end
end
