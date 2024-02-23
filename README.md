# Puppet module for deploying k8s/kubernetes

[![CI](https://github.com/voxpupuli/puppet-k8s/actions/workflows/ci.yml/badge.svg)](https://github.com/voxpupuli/puppet-k8s/actions/workflows/ci.yml)
[![Puppet Forge](https://img.shields.io/puppetforge/v/puppet/k8s.svg)](https://forge.puppet.com/puppet/k8s)
[![Puppet Forge - downloads](https://img.shields.io/puppetforge/dt/puppet/k8s.svg)](https://forge.puppet.com/puppet/k8s)
[![Puppet Forge - endorsement](https://img.shields.io/puppetforge/e/puppet/k8s.svg)](https://forge.puppet.com/puppet/k8s)
[![Puppet Forge - scores](https://img.shields.io/puppetforge/f/puppet/k8s.svg)](https://forge.puppet.com/puppet/k8s)
[![License](https://img.shields.io/github/license/voxpupuli/puppet-k8s.svg)](https://github.com/voxpupuli/puppet-k8s/blob/master/LICENSE)

## Table of Contents

- [Description](#description)
- [Usage](#usage)
- [Examples](#examples)
- [Reference](#reference)

## Description

This module installs, configures, and manages a Kubernetes cluster built from
loose components.

The main focus is towards the current stable versions of K8s (1.18.x+), but it
should be able to handle both older and newer versions without issues.

## Usage

Set k8s::server::etcd_servers to a list of servers or k8s::puppetdb_discovery to `true`.

Setting up a server node (apiserver, controller-manager, scheduler):

```puppet
class { 'k8s':
  role               => 'server',
  control_plane_url  => 'https://kubernetes.example.com:6443',
# generate_ca        => true, # Only set true temporarily to avoid overwriting the old secrets
# puppetdb_discovery => true, # Will use PuppetDB PQL queries to manage etcd and nodes
}
```

Setting up a client node (kubelet, kube-proxy):

```puppet
class { 'k8s':
  role              => 'node',
  control_plane_url => 'https://kubernetes.example.com:6443',
}
```

### Examples

For more in-detail examples see the examples.

- [Simple bridged setup](examples/simple_setup/Readme.md)
- [Cilium setup](examples/cilium/Readme.md)

## Reference

All parameters are documented within the classes. Markdown documentation is available in the [REFERENCE.md](REFERENCE.md) file, it also contains examples.
