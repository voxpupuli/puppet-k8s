# @summary a type to describe a type of Kubernetes node
#
# @note server/control-plane are identical, one using the Puppet term, the other the Kubernetes term
# @note none will install basic components, but not activate any services
type K8s::Node_role = Enum[
  'node',
  'server',
  'control-plane',
  'etcd-replica',
  'none'
]
