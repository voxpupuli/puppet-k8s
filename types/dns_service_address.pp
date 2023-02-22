# a type to describe the dns_service_address
type K8s::Dns_service_address = Variant[
  Stdlib::IP::Address::Nosubnet,
  Array[
    Stdlib::IP::Address::Nosubnet
  ]
]
