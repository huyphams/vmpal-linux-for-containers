# Linux for containers 1

VMPal 0.87, 0.88 and 0.89 download this version. VMPal 0.90 replaced it with version 2.

| | |
|---|---|
| Archive | https://files.vmpal.com/containers/1/vm.aar, 90,737,584 bytes, SHA-256 `531a11a136cf94682c898c3614a7dd9f7f854b778359dff12a3b8795e0312016` |
| `Image` | 28,936,704 bytes, SHA-256 `bf9efb1ba2b095c663d2e9200876c8c85251bc3c8b7d791995b374731e17a16c` |
| `root.ext4` | 1,073,741,824 bytes, SHA-256 `758699066c83c1fc38d209ecf38952751deb2951952db98a5e3587b775f2d290` |
| Kernel | Linux 7.2.11, unmodified, no modules: [huyphams/linux, tag vmpal-v7.2.11](https://github.com/huyphams/linux/tree/vmpal-v7.2.11) |
| Root disk | Alpine Linux 3.24.2 (aarch64): 52 packages from 35 origins, 27 of them copyleft ([packages.tsv](packages.tsv)) |
| BusyBox | Alpine's busybox 1.37.0-r31 (`/bin/busybox`): [huyphams/busybox, tag vmpal-1.37.0-r31](https://github.com/huyphams/busybox/tree/vmpal-1.37.0-r31) |
| BuildKit | `/usr/bin/buildctl`: [v0.33.1](https://github.com/moby/buildkit/tree/v0.33.1) (commit 8c91502cf280bd70a0c50912ce251c46a8881d9f); Alpine's buildkit 0.29.0-r3 package for the daemon |
| Release | [vm-1](https://github.com/huyphams/vmpal-linux-for-containers/releases/tag/vm-1): 27 source tars and 2 Go module zips, 224,244,426 bytes with SHA256SUMS |

## How it was built

- The kernel: on 2026-10-17 in an Ubuntu builder VM (gcc 15.2.0, GNU ld 2.46), from kernel.org's
  `linux-7.2.11.tar.xz`, by the steps of [build-kernel.sh](build-kernel.sh) as VMPal committed it a day later: Apple's
  Containerization `config-arm64` brought up to 7.2.11, plus the options Docker needs. That script didn't yet check
  the tarball against kernel.org's checksums. The configuration it ended with is `VMPal/config-arm64` in the fork,
  the same file as the one in the kernel (`/proc/config.gz`).
- The root disk: [build-root.sh](build-root.sh), on 2026-10-17 in the same builder. It took Alpine 3.24.2's minimal
  root, ran `apk update` and `apk add crun docker buildkit iptables ip6tables iproute2-minimal socat e2fsprogs tar
  zstd tini` (no `apk upgrade`), and compiled vagent. VMPal's `update-agent.sh` replaced vagent in it on 2026-10-18.
  This root still has what VMPal's container engine doesn't run: Docker Engine, containerd, runc, buildx and Alpine's
  buildkit.
- Alpine's docker, containerd, runc, buildkit and docker-cli-buildx packages are Apache-2.0, but their programs link
  MPL-2.0 Go modules. Their tarballs, in the release, carry every module they link in `vendor/`.
- buildctl: BuildKit v0.33.1, built on a Mac with Go 1.26.8 from Go's module cache (CGO off). Built that way, it
  records no version of its own, but each of its 80 modules has the version v0.33.1's go.mod asks for, and the h1
  hash that v0.33.1's go.sum and sum.golang.org give. It links two MPL-2.0 modules:
  github.com/cyphar/filepath-securejoin v0.6.1 (whose pathrs-lite is MPL-2.0) and github.com/hashicorp/go-cleanhttp
  v0.5.2. Their zips are in the release ([go-modules.tsv](go-modules.tsv)).

## Files no package installed

[unpackaged.tsv](unpackaged.tsv) lists them:
- `/sbin/vagent` and `/usr/bin/buildbridge`: VMPal's own (see the [README](../README.md#licenses)).
- `/usr/bin/buildctl`: BuildKit, above.
- `/dev/null`, an empty file the build left (the VM mounts its own `/dev` over it), `/etc/group-` (a backup a
  package's install script made), `/etc/resolv.conf` and `/var/log/apk.log`.
