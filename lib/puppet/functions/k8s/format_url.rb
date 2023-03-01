# frozen_string_literal: true

# Formats a download URL for K8s binaries
Puppet::Functions.create_function(:'k8s::format_url') do
  # @param url The URL template to format
  # @param components A hash of additional arguments
  #
  # @return String A valid download URL
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

    components = components.transform_keys(&:to_sym).merge(
      arch: arch,
      underscore_arch_suffix: underscore_arch_suffix,
      dash_arch_suffix: dash_arch_suffix,
      k3s_arch: k3s_arch,
      kernel: kernel,
      kernel_ext: kernel_ext
    )

    url % components
  end
end
