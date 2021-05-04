# frozen_string_literal: true

Puppet::Functions.create_function(:'k8s::format_url') do
  dispatch :k8s_format_binary do
    param 'String[1]', :url
    param 'Hash[String,Data]', :components
  end

  def k8s_format_binary(url, components)
    scope = closure_scope

    arch = scope['facts'].dig('os', 'architecture')
    arch = 'amd64' if arch.match? %r{x(86_)?64}
    arch = 'arm64' if arch.match? %r{arm64.*|aarch64}
    k3s_arch = arch
    k3s_arch = 'armhf' if arch.match? %r{armv.*}
    k3s_arch = nil if arch == 'amd64'
    arch = 'arm' if arch.match? %r{armv.*}
    arch = '386' if arch == 'i386'

    underscore_arch_suffix = "_#{arch}" unless arch == 'amd64'
    dash_arch_suffix = "-#{arch}" unless arch == 'amd64'

    kernel = scope['facts']['kernel'].downcase
    kernel_ext = 'zip'
    kernel_ext = 'tar.gz' if kernel == 'linux'

    components = Hash[components.map { |k, v| [k.to_sym, v] }].merge(
      arch: arch,
      underscore_arch_suffix: underscore_arch_suffix,
      dash_arch_suffix: dash_arch_suffix,
      k3s_arch: k3s_arch,
      kernel: kernel,
      kernel_ext: kernel_ext,
    )

    url % components
  end
end
