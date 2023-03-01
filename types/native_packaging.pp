# @summary a type to describe Kubernetes native packaging methods
#
# @note hyperkube is a legacy name for single-binary packages
type K8s::Native_packaging = Enum[
  'package',
  'tarball',
  'loose',
  'hyperkube',
  'manual'
]
