# a type to describe api_addn_names
type K8s::Api_addn_names = Array[
  Variant[
    Stdlib::Fqdn,
    Stdlib::IP::Address::Nosubnet,
  ]
]
