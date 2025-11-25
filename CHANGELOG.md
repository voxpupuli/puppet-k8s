# Changelog

All notable changes to this project will be documented in this file.
Each new release typically also includes the latest modulesync defaults.
These should not affect the functionality of the module.

## [v3.0.0](https://github.com/voxpupuli/puppet-k8s/tree/v3.0.0) (2025-11-24)

[Full Changelog](https://github.com/voxpupuli/puppet-k8s/compare/v2.0.1...v3.0.0)

**Breaking changes:**

- Drop puppet, update openvox minimum version to 8.19 [\#137](https://github.com/voxpupuli/puppet-k8s/pull/137) ([TheMeier](https://github.com/TheMeier))
- Update list of OSes to non-EoL versions [\#104](https://github.com/voxpupuli/puppet-k8s/pull/104) ([ananace](https://github.com/ananace))
- Unpack cni\_plugins, crictl & etcd to folders in /opt and use symlinks [\#96](https://github.com/voxpupuli/puppet-k8s/pull/96) ([olavst-spk](https://github.com/olavst-spk))
- Initial work on hiera-ifying and Puppet 8 support for standalone etcd [\#66](https://github.com/voxpupuli/puppet-k8s/pull/66) ([ananace](https://github.com/ananace))

**Implemented enhancements:**

- Add posibility for aditional arguments without values for k8s components [\#129](https://github.com/voxpupuli/puppet-k8s/issues/129)
- Custom CNI binaries do not survive CNI plugin updates [\#107](https://github.com/voxpupuli/puppet-k8s/issues/107)
- Latest Kubernetes binaries are only available on the new repo [\#100](https://github.com/voxpupuli/puppet-k8s/issues/100)
- Replace dependency on kubic \(or provide other alternative\) [\#77](https://github.com/voxpupuli/puppet-k8s/issues/77)
- Add parameter to defer management of /etc/facter/facts.d [\#141](https://github.com/voxpupuli/puppet-k8s/pull/141) ([ananace](https://github.com/ananace))
- puppet/archive Allow 8.x [\#136](https://github.com/voxpupuli/puppet-k8s/pull/136) ([TheMeier](https://github.com/TheMeier))
- Add option to specify main IP family for dualstack [\#123](https://github.com/voxpupuli/puppet-k8s/pull/123) ([ananace](https://github.com/ananace))
- Improve handling of manage\_\* parameters [\#121](https://github.com/voxpupuli/puppet-k8s/pull/121) ([ananace](https://github.com/ananace))
- Make etcd initial\_cluster unique list [\#120](https://github.com/voxpupuli/puppet-k8s/pull/120) ([zezav-cz](https://github.com/zezav-cz))
- metadata.json: Add OpenVox [\#119](https://github.com/voxpupuli/puppet-k8s/pull/119) ([jstraw](https://github.com/jstraw))
- Kubelet labels [\#117](https://github.com/voxpupuli/puppet-k8s/pull/117) ([zezav-cz](https://github.com/zezav-cz))
- Resync bundled resources to modern versions [\#116](https://github.com/voxpupuli/puppet-k8s/pull/116) ([ananace](https://github.com/ananace))
- Retain custom CNI plugins over upgrades [\#114](https://github.com/voxpupuli/puppet-k8s/pull/114) ([ananace](https://github.com/ananace))
- Namespace calls to ensure\_packages [\#113](https://github.com/voxpupuli/puppet-k8s/pull/113) ([ananace](https://github.com/ananace))
- Support configuration of waiting times [\#110](https://github.com/voxpupuli/puppet-k8s/pull/110) ([deric](https://github.com/deric))
- Use pkgs.k8s.io repos instead of kubic [\#103](https://github.com/voxpupuli/puppet-k8s/pull/103) ([ananace](https://github.com/ananace))
- puppetlabs/firewall: Allow 8.x [\#89](https://github.com/voxpupuli/puppet-k8s/pull/89) ([zilchms](https://github.com/zilchms))
- puppet/systemd: Allow 6.x [\#88](https://github.com/voxpupuli/puppet-k8s/pull/88) ([zilchms](https://github.com/zilchms))
- Preliminary SUSE support [\#71](https://github.com/voxpupuli/puppet-k8s/pull/71) ([ananace](https://github.com/ananace))
- Add Puppet 8 support [\#61](https://github.com/voxpupuli/puppet-k8s/pull/61) ([bastelfreak](https://github.com/bastelfreak))

**Fixed bugs:**

- Fix a convergence issue [\#139](https://github.com/voxpupuli/puppet-k8s/pull/139) ([ananace](https://github.com/ananace))
- Fix incompatible key usage errors for etcd v3.5 [\#132](https://github.com/voxpupuli/puppet-k8s/pull/132) ([jorhett](https://github.com/jorhett))
- Breakfix: flannel forbidden to query pod [\#126](https://github.com/voxpupuli/puppet-k8s/pull/126) ([jorhett](https://github.com/jorhett))
- Fix crio package repository, allow data adjustment [\#125](https://github.com/voxpupuli/puppet-k8s/pull/125) ([jorhett](https://github.com/jorhett))
- Correctly handle default name/discovery tag for etcd [\#108](https://github.com/voxpupuli/puppet-k8s/pull/108) ([ananace](https://github.com/ananace))

**Closed issues:**

- Unknown function: puppetdb\_query [\#106](https://github.com/voxpupuli/puppet-k8s/issues/106)
- K8s failes due to service-account.key not being found. [\#105](https://github.com/voxpupuli/puppet-k8s/issues/105)
- cni-plugins, crictl & etcd cannot be updated  [\#95](https://github.com/voxpupuli/puppet-k8s/issues/95)

**Merged pull requests:**

- Un-DRY execs to avoid puppet-lint failures [\#144](https://github.com/voxpupuli/puppet-k8s/pull/144) ([ananace](https://github.com/ananace))
- Fix missing vars for domain cluster [\#135](https://github.com/voxpupuli/puppet-k8s/pull/135) ([zezav-cz](https://github.com/zezav-cz))
- Prevent incorrect installation of runc on 1.28+ crio [\#133](https://github.com/voxpupuli/puppet-k8s/pull/133) ([jorhett](https://github.com/jorhett))
- Bump systemd requirement to support latest [\#115](https://github.com/voxpupuli/puppet-k8s/pull/115) ([ananace](https://github.com/ananace))
- Update binary repos and versions to support modern Kubernetes [\#101](https://github.com/voxpupuli/puppet-k8s/pull/101) ([ananace](https://github.com/ananace))
- update puppet-systemd upper bound to 8.0.0 [\#92](https://github.com/voxpupuli/puppet-k8s/pull/92) ([TheMeier](https://github.com/TheMeier))
- Update Readme - fix table of contents, add badges [\#87](https://github.com/voxpupuli/puppet-k8s/pull/87) ([rwaffen](https://github.com/rwaffen))

## [v2.0.1](https://github.com/voxpupuli/puppet-k8s/tree/v2.0.1) (2024-02-23)

[Full Changelog](https://github.com/voxpupuli/puppet-k8s/compare/v2.0.0...v2.0.1)

**Fixed bugs:**

- kubectl\_apply: add missing require [\#85](https://github.com/voxpupuli/puppet-k8s/pull/85) ([h-haaks](https://github.com/h-haaks))

## [v2.0.0](https://github.com/voxpupuli/puppet-k8s/tree/v2.0.0) (2024-02-21)

[Full Changelog](https://github.com/voxpupuli/puppet-k8s/compare/v1.0.0...v2.0.0)

**Breaking changes:**

- Use a template string for the crictl download URL [\#83](https://github.com/voxpupuli/puppet-k8s/pull/83) ([olavst-spk](https://github.com/olavst-spk))
- Make cni\_plugins download url configurable with a template string [\#82](https://github.com/voxpupuli/puppet-k8s/pull/82) ([olavst-spk](https://github.com/olavst-spk))

**Implemented enhancements:**

- Make Coredns config configurable [\#74](https://github.com/voxpupuli/puppet-k8s/pull/74) ([rwaffen](https://github.com/rwaffen))
- Expose ensure param for container runtime package [\#73](https://github.com/voxpupuli/puppet-k8s/pull/73) ([ananace](https://github.com/ananace))

**Fixed bugs:**

- Do not allow bootstrap tokens with a leading newline [\#80](https://github.com/voxpupuli/puppet-k8s/pull/80) ([olavst-spk](https://github.com/olavst-spk))
- Do not allow bootstrap tokens with a trailing newline [\#79](https://github.com/voxpupuli/puppet-k8s/pull/79) ([olavst-spk](https://github.com/olavst-spk))
- Fix RedHat urls [\#72](https://github.com/voxpupuli/puppet-k8s/pull/72) ([GMZwinge](https://github.com/GMZwinge))

**Merged pull requests:**

- update firewall resources to use jump instead of action; require puppetlabs/firewall 7.x [\#78](https://github.com/voxpupuli/puppet-k8s/pull/78) ([rwaffen](https://github.com/rwaffen))
- Add parameter documentation to every class/define [\#76](https://github.com/voxpupuli/puppet-k8s/pull/76) ([rwaffen](https://github.com/rwaffen))

## [v1.0.0](https://github.com/voxpupuli/puppet-k8s/tree/v1.0.0) (2023-08-07)

[Full Changelog](https://github.com/voxpupuli/puppet-k8s/compare/015d6134ae3d9b40ca539c9439a0de79374bc27a...v1.0.0)

**Breaking changes:**

- remove --container-runtime for k8s versions \> 1.26 [\#65](https://github.com/voxpupuli/puppet-k8s/pull/65) ([rwaffen](https://github.com/rwaffen))
- do more precisely naming [\#59](https://github.com/voxpupuli/puppet-k8s/pull/59) ([rwaffen](https://github.com/rwaffen))
- Drop Puppet 6 support [\#53](https://github.com/voxpupuli/puppet-k8s/pull/53) ([bastelfreak](https://github.com/bastelfreak))

**Implemented enhancements:**

- all K8s::Server::Resources/Kubectl\_apply fail on bootstrapping a new cluster [\#23](https://github.com/voxpupuli/puppet-k8s/issues/23)
- Update ruby code to meet rubocops criterias [\#9](https://github.com/voxpupuli/puppet-k8s/issues/9)
- \[improvement\] Use puppet-kmod module to handle Kernel modules [\#8](https://github.com/voxpupuli/puppet-k8s/issues/8)
- \[improvement\] Use puppet-augeasproviders\_sysctl module to handle sysctl configuration [\#7](https://github.com/voxpupuli/puppet-k8s/issues/7)
- add possibillity to use imagePullSecrets [\#62](https://github.com/voxpupuli/puppet-k8s/pull/62) ([rwaffen](https://github.com/rwaffen))
- puppetlabs/stdlib: Allow 9.x [\#60](https://github.com/voxpupuli/puppet-k8s/pull/60) ([bastelfreak](https://github.com/bastelfreak))
- remove duplicate CRB and move SA to kube-proxy class [\#58](https://github.com/voxpupuli/puppet-k8s/pull/58) ([rwaffen](https://github.com/rwaffen))
- Update container references to active registry [\#57](https://github.com/voxpupuli/puppet-k8s/pull/57) ([ananace](https://github.com/ananace))
- make crictl download url dynamic [\#54](https://github.com/voxpupuli/puppet-k8s/pull/54) ([rwaffen](https://github.com/rwaffen))
- refactor repo.pp - cleanup code, add case instead of if-blocks, remove old debian, only install needed repos [\#49](https://github.com/voxpupuli/puppet-k8s/pull/49) ([rwaffen](https://github.com/rwaffen))
- update etcd installation [\#48](https://github.com/voxpupuli/puppet-k8s/pull/48) ([rwaffen](https://github.com/rwaffen))
- use etcd cluster name also in apiserver to collect only the matching etcd cluster [\#46](https://github.com/voxpupuli/puppet-k8s/pull/46) ([rwaffen](https://github.com/rwaffen))
- Handle file mode for kubeconfig files [\#42](https://github.com/voxpupuli/puppet-k8s/pull/42) ([ananace](https://github.com/ananace))
- Improve bootstrap token handling [\#35](https://github.com/voxpupuli/puppet-k8s/pull/35) ([ananace](https://github.com/ananace))
- Add a wait online class to improve the first-run experience [\#34](https://github.com/voxpupuli/puppet-k8s/pull/34) ([ananace](https://github.com/ananace))

**Fixed bugs:**

- kubelet fails to start when updated to 1.27.x [\#64](https://github.com/voxpupuli/puppet-k8s/issues/64)
- bootstrap token is sensitive, node\_token is not [\#51](https://github.com/voxpupuli/puppet-k8s/issues/51)
- etcd ca gets recreated on each run [\#37](https://github.com/voxpupuli/puppet-k8s/issues/37)
- Expand use of Sensitive to match node tokens [\#52](https://github.com/voxpupuli/puppet-k8s/pull/52) ([ananace](https://github.com/ananace))
- Fix unintentional CA recreation if missing serial [\#40](https://github.com/voxpupuli/puppet-k8s/pull/40) ([ananace](https://github.com/ananace))
- Fix generated kube-proxy configmap [\#27](https://github.com/voxpupuli/puppet-k8s/pull/27) ([ananace](https://github.com/ananace))
- prevent undef value if ipv6 is turned off, fail if not etcd\_servers are defined [\#20](https://github.com/voxpupuli/puppet-k8s/pull/20) ([rwaffen](https://github.com/rwaffen))

**Closed issues:**

- manage kube proxy parameter defaults and name differs between k8s and k8s::node [\#28](https://github.com/voxpupuli/puppet-k8s/issues/28)
- Real world example / Documentation needed [\#18](https://github.com/voxpupuli/puppet-k8s/issues/18)

**Merged pull requests:**

- puppet-lint: list optional parameters after mandatory parameters [\#69](https://github.com/voxpupuli/puppet-k8s/pull/69) ([bastelfreak](https://github.com/bastelfreak))
- Allow latest module dependencies [\#68](https://github.com/voxpupuli/puppet-k8s/pull/68) ([bastelfreak](https://github.com/bastelfreak))
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
