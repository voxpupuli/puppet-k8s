# @summary a type to describe the type of the firewall to use
type K8s::Firewall = Enum[
  'iptables',
  'firewalld',
]
