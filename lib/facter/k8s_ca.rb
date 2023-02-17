# frozen_string_literal: true

# Adds a fact to read the locally stored Kubernetes CA
Facter.add(:k8s_ca) do
  confine { File.exist? '/etc/kubernetes/certs/ca.pem' }
  setcode do
    Base64.strict_encode64(File.read('/etc/kubernetes/certs/ca.pem'))
  end
end
