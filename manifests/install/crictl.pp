# Class: k8s::install::crictl
#
# @summary installs the crictl debugging tool
#
# @param ensure set ensure for installation or deinstallation
# @param version the k8s version
# @param config config for crictl, for example:
#   k8s::install::crictl::config:
#     'runtime-endpoint': 'unix:///run/containerd/containerd.sock'
#     'image-endpoint': 'unix:///run/containerd/containerd.sock'
# @param crictl_package the package name of crictl
# @param manage_repo whether to manage the repo or not
# @param download_url_template template string for the URL to download tar.gz from
#
class k8s::install::crictl (
  Boolean $manage_repo                   = $k8s::manage_repo,
  Hash $config                           = {},
  K8s::Ensure $ensure                    = $k8s::ensure,
  Optional[String[1]] $crictl_package    = $k8s::crictl_package,
  String[1] $version                     = 'v1.26.0',
  Stdlib::HTTPUrl $download_url_template = 'https://github.com/kubernetes-sigs/cri-tools/releases/download/%{version}/crictl-%{version}-linux-%{arch}.tar.gz',
) {
  if $manage_repo {
    include k8s::repo

    $pkg = pick($crictl_package, 'cri-tools')
    package { $pkg:
      ensure => stdlib::ensure($ensure, 'package'),
    }

    Class['k8s::repo'] -> Package[$pkg]

    $config_require = Package[$pkg]
  } else {
    $_url = k8s::format_url($download_url_template, {
        version => $version,
    })
    $_target = "/opt/k8s/crictl-${version}";
    $_tarball_target = '/opt/k8s/archives';

    file { $_target:
      ensure  => stdlib::ensure($ensure, 'directory'),
    }

    archive { 'crictl':
      ensure       => $ensure,
      path         => "${_tarball_target}/crictl-${version}-linux.tar.gz",
      source       => $_url,
      extract      => true,
      extract_path => $_target,
      creates      => "${_target}/crictl",
      cleanup      => true,
    }

    file { '/usr/local/bin/crictl':
      ensure  => stdlib::ensure($ensure, 'link'),
      mode    => '0755',
      replace => true,
      target  => "${_target}/crictl",
      require => Archive['crictl'],
    }

    $config_require = Archive['crictl']
  }

  file { '/etc/crictl.yaml':
    ensure  => $k8s::ensure,
    content => $config.to_yaml,
    require => $config_require,
  }
}
