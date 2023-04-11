# Cilium Setup

It is exactly the same as in the [Simple Setup](../simple_setup/), but we set some different data.

Make sure if this is the default or you explicitly set this data.
We don't want any other cni to be installed in the first place.

```yaml
k8s::node::manage_simple_cni: false
k8s::server::resources::manage_flannel: false
```

The nodes will be in NotReady state at the beginning, because we have no network installed yet.
After puppet has finished, cilium binary can be downloaded and executed.

see: https://docs.cilium.io/en/v1.13/gettingstarted/k8s-install-default/

Execute this on one of the control plane nodes:

```bash
# all defaults
cilium install

# custom setup
cilium install --helm-values /path/to/helm-values.yaml
```

Cilium will completly replace kube-proxy.
It is not needed anymore after installing cilium and can be de-installed.
