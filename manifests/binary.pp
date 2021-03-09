define k8s::binary(
  Enum['present', 'absent'] $ensure = $k8s::ensure,
  String[1] $packaging = $k8s::packaging,
  String[1] $target = "/opt/k8s/${k8s::version}",
  String[1] $tarball_target = '/opt/k8s/archives',

  Boolean $active = true,

  Optional[String] $component = undef,
) {
  if $name in [ 'kubelet', 'kube-proxy' ] {
    $_component = pick($component, 'node')
  } elsif $name in [ 'kube-apiserver', 'kube-controller-manager', 'kube-scheduler' ] {
    $_component = pick($component, 'server')
  } else {
    $_component = pick($component, 'client')
  }

  # Kubelet and kubectl aren't valid to run in a container,
  # so fall back to loose files
  # XXX Do this differently?
  if $name in ['kubelet', 'kubectl'] and $packaging == 'container' {
    $_packaging = 'loose'
  }

  case $_packaging {
    'container': {
      fail('Container management not done yet')
    }
    'package': {
      $_name = k8s::format_url($k8s::package_template, {
        version => $k8s::version,
        component => $_component,
      })
      package { "kubernetes-${name}":
        ensure => $ensure,
        name   => $_name,
      }
    }
    'tarball': {
      $_url = k8s::format_url($k8s::tarball_url_template, {
        version => $k8s::version,
        component => $_component,
      })
      $_file = "${tarball_target}/${basename($_url)}"
      if !defined(File[$tarball_target]) {
        file { $tarball_target:
          ensure  => $ensure ? {
            present => 'directory',
            default => absent,
          },
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
      if $ensure == 'absent' {
        file { "${target}/${name}":
          ensure => absent,
        }
      }
    }
    'loose': {
      $_url = k8s::format_url($k8s::native_url_template, {
        version   => $k8s::version,
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
      $_url = k8s::format_url($k8s::native_url_template, {
        version   => $k8s::version,
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
    }
    default: {
      fail('Invalid packaging specified')
    }
  }

  if $active and !($k8s::packaging in ['container', 'package']) {
    file { "/usr/bin/${name}":
      ensure => $ensure,
      target => "${target}/${name}",
    }
  }
}
