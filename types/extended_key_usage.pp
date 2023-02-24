# @summary a type to describe extended_key_usage
type K8s::Extended_key_usage = Array[
  Enum[
    'clientAuth',
    'serverAuth'
  ]
]
