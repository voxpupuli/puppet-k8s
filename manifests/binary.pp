# @summary Deploys a Kubernetes binary
define k8s::binary (
  K8s::Ensure $ensure       = $k8s::ensure,
  String[1] $version        = $k8s::version,
  String[1] $packaging      = $k8s::packaging,
  String[1] $target         = "/opt/k8s/${$version}",
  String[1] $tarball_target = '/opt/k8s/archives',

  Boolean $active = true,

  Optional[String] $component = undef,
) {
  if $name in ['kubelet', 'kube-proxy'] {
    $_component = pick($component, 'node')
  } elsif $name in ['kube-apiserver', 'kube-controller-manager', 'kube-scheduler'] {
    $_component = pick($component, 'server')
  } else {
    $_component = pick($component, 'client')
  }

  if !defined(File[$target]) {
    file { $target:
      ensure => stdlib::ensure($ensure, 'directory'),
    }
  }

  # Always install kubelet and kubectl as binaries
  if $packaging == 'native' or ($packaging == 'container' and $name in ['kubelet', 'kubectl']) {
    $_packaging = $k8s::native_packaging
  } else {
    $_packaging = $packaging
  }

  case $_packaging {
    'container': {}
    'package': {
      $_template = $k8s::package_template
      $_name = k8s::format_url($_template, {
          version => $version,
          component => $_component,
      })
      package { "kubernetes-${name}":
        ensure => $ensure,
        name   => $_name,
      }

      if !defined(File["${target}/${name}"]) {
        file { "${target}/${name}":
          ensure => $ensure,
          mode   => '0755',
          target => "/usr/bin/${name}",
        }
      }
    }
    'tarball': {
      $_template = $k8s::tarball_url_template
      $_url = k8s::format_url($_template, {
          version => $version,
          component => $_component,
      })
      $_file = "${tarball_target}/${basename($_url)}"
      if !defined(File[$tarball_target]) {
        file { $tarball_target:
          ensure  => stdlib::ensure($ensure, 'directory'),
          purge   => true,
          recurse => true,
        }
      }

      archive { "${name} from ${_file}":
        ensure          => $ensure,
        path            => $_file,
        source          => $_url,
        extract         => true,
        extract_command => "tar -C '${target}' -xf %s --transform 's/.*\\///' --wildcards '*${name}'",
        extract_path    => $target,
        cleanup         => true,
        creates         => "${target}/${name}",
      }
      if !defined(File["${target}/${name}"]) {
        file { "${target}/${name}":
          ensure  => $ensure,
          mode    => '0755',
          replace => false,
        }
      }
    }
    'loose': {
      $_template = $k8s::native_url_template
      $_url = k8s::format_url($_template, {
          version   => $version,
          component => $_component,
          binary    => $name,
      })
      file { "${target}/${name}":
        ensure => $ensure,
        mode   => '0755',
        source => $_url,
      }
    }
    'hyperkube': {
      $_template = $k8s::native_url_template
      $_url = k8s::format_url($_template, {
          version   => $version,
          component => $_component,
          binary    => $k8s::hyperkube_name,
      })
      if !defined(File["${target}/${k8s::hyperkube_name}"]) {
        file { "${target}/${k8s::hyperkube_name}":
          ensure => $ensure,
          mode   => '0755',
          source => $_url,
        }
      }
      file { "${target}/${name}":
        ensure => $ensure,
        mode   => '0755',
        target => "${target}/${k8s::hyperkube_name}",
      }
    }
    'manual': {
      # User is expected to have created ${target}/${name} now
      File<| $title == "${target}/${name}" |> {}
    }
    default: {
      fail('Invalid packaging specified')
    }
  }

  if $active and $packaging != 'container' and !defined(File["/usr/bin/${name}"]) {
    if $packaging == 'package' {
      file { "/usr/bin/${name}":
        ensure  => $ensure,
        mode    => '0755',
        replace => false,
      }
    } else {
      file { "/usr/bin/${name}":
        ensure => $ensure,
        mode   => '0755',
        target => "${target}/${name}",
      }
    }
  }
}
