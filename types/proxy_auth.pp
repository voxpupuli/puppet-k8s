# @summary a type to describe kube-proxy authentication methods
type K8s::Proxy_auth = Enum[
  'cert',
  'token',
  'incluster'
]
