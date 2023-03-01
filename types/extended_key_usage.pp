# @summary a type to describe extended key usage for a TLS certificate
type K8s::Extended_key_usage = Array[
  Enum[
    'clientAuth',
    'serverAuth'
  ]
]
