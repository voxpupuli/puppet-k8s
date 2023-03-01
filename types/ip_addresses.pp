# @summary a type to describe multiple IP addresses without subnet sizes
type K8s::IP_addresses = Variant[
  Stdlib::IP::Address::Nosubnet,
  Array[
    Stdlib::IP::Address::Nosubnet,
    1
  ]
]
