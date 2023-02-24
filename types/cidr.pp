# @summary a type to describe the cidr
type K8s::Cidr = Variant[
  Stdlib::IP::Address::V4::CIDR,
  Stdlib::IP::Address::V6::CIDR,
  Array[
    Variant[
      Stdlib::IP::Address::V4::CIDR,
      Stdlib::IP::Address::V6::CIDR
    ]
  ]
]
