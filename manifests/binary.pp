define k8s::binary(
  Enum['present', 'absent'] $ensure = $k8s::ensure,
  String[1] $name = $title,
  String[1] $target = "/op/k8s/${k8s::version}",
  String[1] $tarball_target = $target,

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

  case $k8s::packaging {
    'container': {
      fail('Container management not done yet')
    }
    'package': {
      $_name = k8s_format_binary($k8s::package_template, {
        version => $k8s::version,
        component => $_component,
      })
      package { "kubernetes-${name}":
        ensure => $ensure,
        name   => $_name,
      }
    }
    'tarball': {
      $_url = k8s_format_binary($k8s::tarball_url_template, {
        version => $k8s::version,
        component => $_component,
      })
      $_file = "${tarball_target}/${basename($_url)}"
      if !defined(File[$_file]) {
        file { $_file:
          ensure  => $ensure,
          backup  => false,
          replace => false,
          source  => $_url,
        }
      }
      if $ensure == 'present' {
        exec { "Extract ${name} from k8s tarball":
          command  => "tar -C '${target}' -xf '${_file}' --transform 's/.*\\///' --wildcards '*${name}'",
          creates  => "${target}/${name}",
          path     => ['/usr/bin', '/bin'],
          requires => File[$_file],
        }
      }
    }
    'loose': {
      $_url = k8s_format_binary($k8s::native_url_template, {
        version   => $k8s::version,
        component => $_component,
        binary    => $name,
      })
      file { "${target}/${game}":
        ensure => $ensure,
        mode   => '0755',
        source => $_url,
      }
    }
    'hyperkube': {
      $_url = k8s_format_binary($k8s::native_url_template, {
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
  }

  if $active and !($packaging in ['container', 'package']) {
    file { "/usr/bin/${name}":
      ensure => $ensure,
      target => "${target}/${name}",
    }
  }
}
