# @summary @summary a type to describe native_packaging
type K8s::Native_packaging = Enum[
  'package',
  'tarball',
  'loose',
  'hyperkube',
  'manual'
]
