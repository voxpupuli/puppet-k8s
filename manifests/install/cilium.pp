# Class: k8s::install::cilium
#
# @summary installs cilium k8s cni networking
#
# @param version sets the version to use
# @param arch sets the arch to use for binary download
# @param checksum the checksum to verify the download
# @param checksum_type which algorithm the checksum was created with, has to be checked with
# @param incluster_version cilium internal version number in the cluster pods
#
class k8s::install::cilium (
  String[1] $version       = 'v0.13.1',
  String[1] $arch          = 'amd64',
  String[1] $checksum      = 'dfabb7a080cd2ae40c71e51980183949bd5ce76184ac439ef32f988825cb275d',
  String[1] $checksum_type = 'sha256',
  String[1] $incluster_version = '1.13.0',
) {
  archive { 'cilium':
    path          => "/tmp/cilium-linux-${arch}.tar.gz",
    source        => "https://github.com/cilium/cilium-cli/releases/download/${version}/cilium-linux-${arch}.tar.gz",
    checksum      => $checksum,
    checksum_type => $checksum_type,
    extract       => true,
    extract_path  => '/usr/local/bin',
    creates       => '/usr/local/bin/cilium',
    cleanup       => true,
  }

  # TODO: make this work
  # exec { 'cilium install':
  #   path        => $facts['path'],
  #   environment => ['KUBECONFIG=/root/.kube/config'],
  #   command     => "cilium install --version ${incluster_version}",
  #   onlyif      => 'cilium status | grep "daemonsets.apps \"cilium\" not found"',
  # }
}
