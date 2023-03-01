# @summary a type to describe node/kubelet authentication methods
type K8s::Node_auth = Enum[
  'cert',
  'token',
  'bootstrap'
]
