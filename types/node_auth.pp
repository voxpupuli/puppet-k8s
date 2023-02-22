# a type to describe the node auth
type K8s::Node_auth = Enum[
  'cert',
  'token',
  'bootstrap'
]
