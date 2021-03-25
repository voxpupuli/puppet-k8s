define k8s::server::bootstrap_token(
  Stdlib::Unixpath $kubeconfig,

  String[6,6] $id = $name,
  String[16,16] $secret = fqdn_rand_string(16),
  Optional[String] $description = undef,
  Optional[K8s::Timestamp] $expiration = undef,
  Optional[Boolean] $use_authentication = undef,
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
    $v =~ String[1]
  }.map |$k, $v| {
    [$k, Binary.new($v, '%s')]
  })

  kubectl_apply { "bootstrap-token-${id}":
    kubeconfig  => $kubeconfig,
    namespace   => 'kube-system',

    api_version => 'v1',
    kind        => 'Secret',

    data        => {
      'type' => 'bootstrap.kubernetes.io/token',
      'data' => $_secret_data,
    } + $addn_data,
  }
}
