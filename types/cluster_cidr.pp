# a type to describe the cluster_cidr
type K8s::Cluster_cidr = Variant[
  Stdlib::IP::Address::V4::CIDR,
  Stdlib::IP::Address::V6::CIDR,
  Array[
    Variant[
      Stdlib::IP::Address::V4::CIDR,
      Stdlib::IP::Address::V6::CIDR
    ]
  ]
]
