# Simple Setup

With this two profiles on can setup a simple cluster with bridged network.

The control plane can also act as a worker but for this example it is disabled.
Have also a look at the data. With this the CA will be auto-generated and deployed.

This example only works if a puppetdb is present.
On an empty puppetdb or very first run you might have to run puppet twice on the control plane.

```
examples/simple_setup
├── Readme.md
├── data
│   ├── common.yaml
│   └── nodes
│       ├── controller.yaml
│       └── worker.yaml
└── manifests
    ├── controller.pp
    └── worker.pp
```
