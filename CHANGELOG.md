# Changelog

All notable changes to this project will be documented in this file.
Each new release typically also includes the latest modulesync defaults.
These should not affect the functionality of the module.

## [v1.0.0](https://github.com/voxpupuli/puppet-k8s/tree/v1.0.0) (2023-04-27)

[Full Changelog](https://github.com/voxpupuli/puppet-k8s/compare/015d6134ae3d9b40ca539c9439a0de79374bc27a...v1.0.0)

**Implemented enhancements:**

- Update ruby code to meet rubocops criterias [\#9](https://github.com/voxpupuli/puppet-k8s/issues/9)
- \[improvement\] Use puppet-kmod module to handle Kernel modules [\#8](https://github.com/voxpupuli/puppet-k8s/issues/8)
- \[improvement\] Use puppet-augeasproviders\_sysctl module to handle sysctl configuration [\#7](https://github.com/voxpupuli/puppet-k8s/issues/7)
- refactor repo.pp - cleanup code, add case instead of if-blocks, remove old debian, only install needed repos [\#49](https://github.com/voxpupuli/puppet-k8s/pull/49) ([rwaffen](https://github.com/rwaffen))
- update etcd installation [\#48](https://github.com/voxpupuli/puppet-k8s/pull/48) ([rwaffen](https://github.com/rwaffen))
- use etcd cluster name also in apiserver to collect only the matching etcd cluster [\#46](https://github.com/voxpupuli/puppet-k8s/pull/46) ([rwaffen](https://github.com/rwaffen))
- Improve bootstrap token handling [\#35](https://github.com/voxpupuli/puppet-k8s/pull/35) ([ananace](https://github.com/ananace))
- Add a wait online class to improve the first-run experience [\#34](https://github.com/voxpupuli/puppet-k8s/pull/34) ([ananace](https://github.com/ananace))

**Fixed bugs:**

- etcd ca gets recreated on each run [\#37](https://github.com/voxpupuli/puppet-k8s/issues/37)
- Fix unintentional CA recreation if missing serial [\#40](https://github.com/voxpupuli/puppet-k8s/pull/40) ([ananace](https://github.com/ananace))
- Fix generated kube-proxy configmap [\#27](https://github.com/voxpupuli/puppet-k8s/pull/27) ([ananace](https://github.com/ananace))
- prevent undef value if ipv6 is turned off, fail if not etcd\_servers are defined [\#20](https://github.com/voxpupuli/puppet-k8s/pull/20) ([rwaffen](https://github.com/rwaffen))

**Closed issues:**

- manage kube proxy parameter defaults and name differs between k8s and k8s::node [\#28](https://github.com/voxpupuli/puppet-k8s/issues/28)
- Real world example / Documentation needed [\#18](https://github.com/voxpupuli/puppet-k8s/issues/18)

**Merged pull requests:**

- fix forgotten user and group values [\#41](https://github.com/voxpupuli/puppet-k8s/pull/41) ([rwaffen](https://github.com/rwaffen))
- Revert "Include every IP address into a cert's SAN field" [\#39](https://github.com/voxpupuli/puppet-k8s/pull/39) ([ananace](https://github.com/ananace))
- make user and group dynamic [\#38](https://github.com/voxpupuli/puppet-k8s/pull/38) ([rwaffen](https://github.com/rwaffen))
- Update docu [\#33](https://github.com/voxpupuli/puppet-k8s/pull/33) ([rwaffen](https://github.com/rwaffen))
- Include every IP address into a cert's SAN field [\#32](https://github.com/voxpupuli/puppet-k8s/pull/32) ([jay7x](https://github.com/jay7x))
- Some improvements to certificate generation [\#30](https://github.com/voxpupuli/puppet-k8s/pull/30) ([ananace](https://github.com/ananace))
- Improve the kube-proxy management flag [\#29](https://github.com/voxpupuli/puppet-k8s/pull/29) ([ananace](https://github.com/ananace))
- Split out managed resources into separate classes [\#26](https://github.com/voxpupuli/puppet-k8s/pull/26) ([ananace](https://github.com/ananace))
- Use cascade=orphan for kubectl\_apply resources when told to recreate [\#25](https://github.com/voxpupuli/puppet-k8s/pull/25) ([ananace](https://github.com/ananace))
- add features [\#24](https://github.com/voxpupuli/puppet-k8s/pull/24) ([rwaffen](https://github.com/rwaffen))
- Patching v3 [\#21](https://github.com/voxpupuli/puppet-k8s/pull/21) ([rwaffen](https://github.com/rwaffen))
- add some patches to get this working [\#19](https://github.com/voxpupuli/puppet-k8s/pull/19) ([rwaffen](https://github.com/rwaffen))
- Use herculesteam-augeasproviders\_sysctl to manage sysctl settings [\#16](https://github.com/voxpupuli/puppet-k8s/pull/16) ([SimonHoenscheid](https://github.com/SimonHoenscheid))
- Use puppet-kmod to manage kernel\_modules [\#15](https://github.com/voxpupuli/puppet-k8s/pull/15) ([SimonHoenscheid](https://github.com/SimonHoenscheid))
- Update names/documentation on type aliases [\#13](https://github.com/voxpupuli/puppet-k8s/pull/13) ([ananace](https://github.com/ananace))
- fix rubocop complains, activate rubocop again, add .rubocop\_todo.yml [\#10](https://github.com/voxpupuli/puppet-k8s/pull/10) ([SimonHoenscheid](https://github.com/SimonHoenscheid))
- Fix linting and add some type\_aliases [\#5](https://github.com/voxpupuli/puppet-k8s/pull/5) ([rwaffen](https://github.com/rwaffen))
- Add barebone documentation to missing places [\#4](https://github.com/voxpupuli/puppet-k8s/pull/4) ([ananace](https://github.com/ananace))
- modulesync 5.4.0 [\#3](https://github.com/voxpupuli/puppet-k8s/pull/3) ([ananace](https://github.com/ananace))
- Fixup tests to work with vox modulesync [\#2](https://github.com/voxpupuli/puppet-k8s/pull/2) ([ananace](https://github.com/ananace))
- Add dual-stack support for DNS service configuration [\#1](https://github.com/voxpupuli/puppet-k8s/pull/1) ([ananace](https://github.com/ananace))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
