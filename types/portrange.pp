# @summary This regexp matches port range values
type K8s::PortRange = Pattern[/^[0-9]+(-[0-9]+)?$/]
