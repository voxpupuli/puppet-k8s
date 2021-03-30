Facter.add(:k8s_versions) do
  all_components = [
    # Server components
    'kube-apiserver',
    'kube-controller-manager',
    'kube-scheduler',
    # Node components
    'kubelet',
    'kube-proxy',
    # Misc components
    'kubectl',
  ].freeze

  confine do
    all_components.any? { |c| Facter::Core::Execution.which(c) }
  end

  setcode do
    versions = {}
    if Facter::Core::Execution.which('kubectl')
      output = Facter::Util::Resolution.exec('kubectl version --client')
      versions['kubectl'] = output.scan(%r{GitVersion:"(.+?)"}).flatten.first
    end

    all_components.each do |comp|
      next if comp == 'kubectl'
      next unless Facter::Core::Execution.which(comp)

      output = Facter::Util::Resolution.exec("#{comp} --version")
      version[comp] = output.scan(%r{Kubernetes v(.+)}).flatten.first
    end

    versions
  end
end
