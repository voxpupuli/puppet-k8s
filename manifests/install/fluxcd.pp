# @summary Installs the FluxCD CLI, and optionally also installs Flux into on the cluster
#
# @example Install - and automatically update - latest version of Flux
#   class { 'k8s::install::fluxcd':
#     ensure => latest,
#   }
#
# @example Install flux with different components
#   class { 'k8s::install::fluxcd':
#     install_options => {
#       components       => ['source-controller', 'kustomize-controller']
#       components_extra => ['source-watcher', 'image-reflector-controller']
#     }
#   }
#
# @param ensure The FluxCD version to install, or present/latest for the latest at the time
# @param install If FluxCD should be installed into the local cluster, will default to true on k8s::server nodes
# @param install_options Additional options to provide to the `flux install` invocation
# @param upgrade Upgrade FluxCD on the local cluster if the version changes
# @param install_dir Where to install the FluxCD binary
# @param kubeconfig The kubeconfig file to use when installing/upgrading FluxCD
class k8s::install::fluxcd (
  Variant[Enum['absent', 'present', 'latest'], String[1]] $ensure = 'present',

  Optional[Boolean] $install = undef,
  Hash[String, Data] $install_options = {},
  Boolean $upgrade = true,

  Stdlib::Unixpath $install_dir = '/usr/local/bin',
  Stdlib::Unixpath $kubeconfig = '/root/.kube/config',
) {
  if $ensure == 'absent' {
    file { '/usr/local/bin/flux':
      ensure => absent,
    }
    tidy { 'Old FluxCD installs':
      path    => $install_dir,
      recurse => 1,
      matches => 'flux-*',
    }
    return()
  }

  if $ensure == 'latest' or $ensure == 'present' {
    $latest = extlib::version_latest_github('fluxcd/flux2')
    $_version = $latest.regsubst('^v?(.+)$', '\1', 'I')
  } else {
    $_version = $ensure
    $latest = "v${_version}"
  }

  if $_version !~ Pattern[/^\d+(\.\d+){2}$/] {
    fail("Version '${_version}' is not a valid FluxCD version")
  }

  if $ensure == 'present' {
    $path = "${install_dir}/flux"
    $transform_command = ''
  } else {
    # Use version-specific flux binary, so that the archive resource detects version changes
    $path = "${install_dir}/flux-${_version}"
    $transform_command = "--transform='s/flux/flux-${_version}/'"

    Archive['FluxCD CLI']
    -> file { "${install_dir}/flux":
      ensure  => link,
      target  => $path,
      replace => true,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
    }
    ~> tidy { 'Old FluxCD installs':
      path    => $install_dir,
      recurse => 1,
      matches => 'flux-*',
    }
  }

  archive { 'FluxCD CLI':
    ensure          => present,
    path            => '/tmp/fluxcd.tar.gz',
    source          => "https://github.com/fluxcd/flux2/releases/download/${latest}/flux_${_version}_linux_amd64.tar.gz",
    extract         => true,
    extract_command => "tar -C /usr/local/bin -xf %s ${transform_command} flux",
    extract_path    => $install_dir,
    cleanup         => true,
    creates         => $path,
  }
  -> file { $path:
    ensure  => file,
    replace => false,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
  }

  if pick($install, defined('k8s::server')) {
    $install_flags = $install_options.map |$flag, $value| {
      if $value =~ Array {
        $_value = $value.join(',')
      }
      "--${flag.regsubst('_', '-')}=${_value}"
    }

    # Check if namespace exists, otherwise trigger install
    # TODO: trigger install if install_flags have changed?
    Exec <| title == 'k8s apiserver wait online' |>
    -> exec { 'Verify FluxCD install':
      path    => $facts['path'],
      command => 'true',
      unless  => "kubectl --kubeconfig ${kubeconfig} get namespace flux-system",
    }
    ~> exec { 'FluxCD install':
      command     => "flux install --export ${install_flags.join(' ')} | kubectl --kubeconfig ${kubeconfig} apply --server-side --force-conflicts -f -",
      refreshonly => true,
      path        => $facts['path'],
      require     => File['/usr/local/bin/flux'],
    }
    # If kubeconfig is managed, ensure it exists before Flux
    File <| title == $kubeconfig |> -> Exec['FluxCD install']
    Kubeconfig <| title == $kubeconfig |> -> Exec['FluxCD install']

    if $upgrade {
      # Trigger (re)install on every version change
      Archive['FluxCD CLI'] ~> Exec['FluxCD install']
    }
  }
}
