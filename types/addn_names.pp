# a type to describe addn_names
type K8s::Addn_names = Array[
  Optional[
    Variant[
      Stdlib::Fqdn,
      Stdlib::IP::Address::Nosubnet,
    ]
  ]
]
