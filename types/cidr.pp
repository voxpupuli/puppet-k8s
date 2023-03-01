# @summary a type to describe one or more IPv4/6 CIDR
type K8s::CIDR = Variant[
  Stdlib::IP::Address::V4::CIDR,
  Stdlib::IP::Address::V6::CIDR,
  Array[
    Variant[
      Stdlib::IP::Address::V4::CIDR,
      Stdlib::IP::Address::V6::CIDR
    ],
    1
  ]
]
