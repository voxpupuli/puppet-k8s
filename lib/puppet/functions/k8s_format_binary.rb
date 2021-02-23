Puppet::Functions.create_function(:k8s_format_binary) do
  dispatch :k8s_format_binary do
    param 'String[1]', :url
    param 'Hash[String,Data]', :components
  end

  def k8s_format_binary(url, components)
    arch = facts.dig('os', 'architecture')
    arch = 'amd64' if arch == /x(86_)?64/
    arch = 'arm64' if arch == /arm64.*|aarch64/
    k3s_arch = arch
    k3s_arch = 'armhf' if arch =~ /armv.*/
    k3s_arch = nil if arch == 'amd64'
    arch = 'arm' if arch =~ /armv.*/
    arch = '386' if arch == 'i386'

    underscore_arch_suffix = "_#{arch}" unless arch == 'amd64'
    dash_arch_suffix = "-#{arch}" unless arch == 'amd64'

    kernel = facts['kernel'].downcase

    sprintf(url, components.merge(
      arch: arch,
      underscore_arch_suffix: underscore_arch_suffix,
      dash_arch_suffix: dash_arch_suffix,
      k3s_arch: k3s_arch,
      kernel: kernel
    ))
  end
end
