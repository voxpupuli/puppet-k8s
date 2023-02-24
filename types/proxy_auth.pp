# @summary a type to describe the kube-proxy auth
type K8s::Proxy_auth = Enum[
  'cert',
  'token',
  'incluster'
]
