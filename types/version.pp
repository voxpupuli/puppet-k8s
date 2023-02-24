# @summary A type for handling Kubernetes version numbers
type K8s::Version = Pattern[/^(\d+\.){2}\d+$/]
