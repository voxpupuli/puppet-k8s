# @summary a type to describe tls_altnames
type K8s::Tls_altnames = Array[
  Variant[
    Stdlib::Fqdn,
    Stdlib::IP::Address::Nosubnet,
  ]
]
