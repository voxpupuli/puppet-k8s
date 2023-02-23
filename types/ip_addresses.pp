# a type to describe the ip_addresses
type K8s::Ip_addresses = Variant[
  Stdlib::IP::Address::Nosubnet,
  Array[
    Stdlib::IP::Address::Nosubnet
  ]
]
