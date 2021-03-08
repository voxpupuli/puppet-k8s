class k8s::server::tls(
  Boolean $generate_ca = $k8s::server::generate_ca,
  Array[
    Variant[
      Stdlib::Fqdn,
      Stdlib::IP::Address::Nosubnet,
    ]
  ] $api_addn_names = [],
) {
  # Generate CA - if necessary
  # Generate API cert/key - if necessary
  # Generate Admin cert/key - if necessary
}
