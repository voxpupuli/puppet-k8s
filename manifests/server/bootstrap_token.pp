define k8s::server::bootstrap_token(
  Enum['present', 'absent'] $ensure = 'present',
  Stdlib::Unixpath $kubeconfig,

  String[6,6] $id = $name,
  String[16,16] $secret = fqdn_rand_string(16).downcase(),
  Boolean $use_authentication = true,

  Optional[String] $description = undef,
  Optional[K8s::Timestamp] $expiration = undef,
  Optional[Boolean] $use_signing = undef,
  Optional[Array[String]] $extra_groups = undef,

  Hash[String,Data] $addn_data = {}
) {
  $_extra_groups = pick($extra_groups, []).join(',')
  $_secret_data = Hash({
    'token-id'                       => $id,
    'token-secret'                   => $secret,
    'description'                    => $description,
    'expiration'                     => $expiration,
    'usage-bootstrap-authentication' => $use_authentication,
    'usage-bootstrap-signing'        => $use_signing,
    'auth-extra-groups'              => $_extra_groups,
  }.filter |$k, $v| {
    $v != undef and $v != ''
  }.map |$k, $v| {
    [$k, "${Binary.new("${v}", '%s')}"]
  })

  kubectl_apply { "bootstrap-token-${id}":
    ensure      => $ensure,
    provider    => 'kubectl',
    kubeconfig  => $kubeconfig,
    namespace   => 'kube-system',
    update      => false,

    api_version => 'v1',
    kind        => 'Secret',

    content     => {
      'type' => 'bootstrap.kubernetes.io/token',
      'data' => $_secret_data,
    } + $addn_data,
  }
}
