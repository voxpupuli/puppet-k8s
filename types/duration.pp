# @summary This regexp matches Go duration values, as taken from;
# https://golang.org/pkg/time/#ParseDuration
type K8s::Duration = Pattern[/^(-?[0-9]+(\.[0-9]+)?(ns|us|µs|ms|s|m|h))+$/]
