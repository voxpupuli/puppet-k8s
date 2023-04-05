# @summary a type to describe how kube-proxy should be deployed
type K8s::Proxy_method = Variant[
  Enum[
    'on-node',
    'in-cluster',
  ],
  Boolean
]
