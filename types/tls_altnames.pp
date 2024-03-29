# @summary a type to describe TLS alternative names in certificates
type K8s::TLS_altnames = Array[
  Variant[
    Stdlib::Fqdn,
    Stdlib::IP::Address::Nosubnet,
  ]
]
