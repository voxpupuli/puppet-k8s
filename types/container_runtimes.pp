# @summary a type to describe the supported container runtimes
type K8s::Container_runtimes = Enum[
  'docker',
  'crio',
  'containerd'
]
