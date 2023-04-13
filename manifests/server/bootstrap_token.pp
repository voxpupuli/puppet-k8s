# @summary Generates and stores a kubelet bootstrap token into the cluster
#
# You generally only want this to be done on a single Kubernetes server
define k8s::server::bootstrap_token (
  K8s::Ensure $ensure = 'present',
  Stdlib::Unixpath $kubeconfig,

  Pattern[/^[a-z0-9]{6}$/] $id            = $name,
  Sensitive[K8s::Bootstrap_token] $secret = Sensitive(fqdn_rand_string(16).downcase()),
  Boolean $use_authentication             = true,
  Boolean $update                         = false,

  Optional[String] $description         = undef,
  Optional[K8s::Timestamp] $expiration  = undef,
  Optional[Boolean] $use_signing        = undef,
  Optional[Array[String]] $extra_groups = undef,

  Hash[String,Data] $addn_data = {}
) {
  $_extra_groups = pick($extra_groups, []).join(',')
  $_secret_data = Hash({
      'token-id'                       => $id,
      'token-secret'                   => $secret.unwrap,
      'description'                    => $description,
      'expiration'                     => $expiration,
      'usage-bootstrap-authentication' => $use_authentication,
      'usage-bootstrap-signing'        => $use_signing,
      'auth-extra-groups'              => $_extra_groups,
    }.filter |$k, $v| {
      $v != undef and $v != ''
    }.map |$k, $v| {
      [$k, String(Binary.new(String($v), '%s'))]
  })

  kubectl_apply { "bootstrap-token-${id}":
    ensure      => $ensure,
    provider    => 'kubectl',
    kubeconfig  => $kubeconfig,
    namespace   => 'kube-system',
    update      => $update,

    api_version => 'v1',
    kind        => 'Secret',

    content     => {
      'type' => 'bootstrap.kubernetes.io/token',
      'data' => $_secret_data,
    }.deep_merge($addn_data),
  }
}
