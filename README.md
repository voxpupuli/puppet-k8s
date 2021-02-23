# hyperkube

## Table of Contents

- [Description](#description)
- [Setup](#setup)
- [Usage](#usage)
- [Development](#development)

---

## Description

This module installs, configures, and manages a Kubernetes cluster through
the use of the combined hyperkube binary.

The main focus is towards the current stable version of K8s (1.16.x), but it
should be able to handle both older and newer versions without issues.
Do note that bare-metal will require specifying URLs and hashes for the
exact version that you require.

## Setup

To set up a docker-ized Kubernetes node on the current machine, linked to
the K8s cluster running on server 10.0.0.2:
```
class { 'hyperkube':
  api_server => 'https://10.0.0.2:6443',
  role       => 'node',
}
```

To set up a control plane (apiserver, scheduler, controller manager) on
the current machine:
```
class { 'hyperkube':
  role => 'control_plane',
}
```

## Usage



## Reference

All parameters are documented within the classes. Markdown documentation is available in the [REFERENCE.md](REFERENCE.md) file, it also contains examples.

## Development

This project contains tests for [rspec-puppet](http://rspec-puppet.com/).

Quickstart to run all linter and unit tests:

```bash
bundle install --path .vendor/ --without system_tests --without development --without release
bundle exec rake test
```

## Authors

This module was written by [Alexander 'Ananace' Olofsson](https://github.com/ananace).
