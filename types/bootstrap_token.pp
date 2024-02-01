# @summary A Kubernetes bootstrap token, must be 16-characters lowercase alphanumerical
type K8s::Bootstrap_token = Pattern[/\A[a-z0-9]{16}\z/]
