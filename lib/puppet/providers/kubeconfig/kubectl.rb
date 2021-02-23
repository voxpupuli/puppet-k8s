Puppet::Type.type(:kubeconfig).provide(:kubectl, parent: :ruby) do
  commands :kubectl => 'kubectl'

  def update_cluster
    params = []
    params << "--embed-certs=#{resource[:embed_certs]}" if resource[:embed_certs]
    params << "--server=#{resource[:server]}" if resource[:server]
    params << "--certificate-authority=#{resource[:ca_cert]}" if resource[:ca_cert]
    params << "--insecure-skip-tls-verify=#{resource[:skip_tls_verify]}" if resource[:skip_tls_verify]
    params << "--tls-server-name=#{resource[:tls_server_name]}" if resource[:tls_server_name]

    kubectl(
      'config', 'set-cluster',
      resource[:cluster],
      *params
    )
  end

  def update_context
    params = []
    params << "--cluster=#{resource[:cluster]}"
    params << "--context=#{resource[:context]}"
    params << "--user=#{resource[:user]}"

    kubectl(
      'config', 'set-context',
      resource[:context],
      *params
    )
  end

  def update_credentials
    params = []
    params << "--embed-certs=#{resource[:embed_certs]}" if resource[:embed_certs]
    params << "--client-certificate=#{resource[:client_cert]}" if resource[:client_cert]
    params << "--client-key=#{resource[:client_key]}" if resource[:client_key]
    params << "--token=#{resource[:token]}" if resource[:token]
    params << "--token=#{File.read(resource[:token_file]).strip}" if resource[:token_file]
    params << "--username=#{resource[:username]}" if resource[:username]
    params << "--password=#{resource[:password]}" if resource[:password]

    kubectl(
      'config', 'set-context',
      resource[:context],
      *params
    )
  end

  def save; end
end
