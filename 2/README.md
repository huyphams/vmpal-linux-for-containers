# Linux for containers 2

VMPal 0.90 and later download this version. It replaced version 1.

| | |
|---|---|
| Archive | https://files.vmpal.com/containers/2/vm.aar, 34,453,660 bytes, SHA-256 `53095b4af9b60a76d9d7a10e7a98fa29a6756b5b0d3d66a0f35d729a169bf964` |
| `Image` | 29,178,368 bytes, SHA-256 `3904222444b7e2444261b03177be45f984ba21d5afe34d50bea6c7a65f3fb5ad` |
| `root.ext4` | 1,073,741,824 bytes, SHA-256 `71bc489d9ab827600c8a39f3dcab18dcba89057fd025d57faa3b377cbdad8010` |
| Kernel | Linux 7.3 (it calls itself 7.3.0), unmodified, no modules: [huyphams/linux, tag vmpal-v7.3](https://github.com/huyphams/linux/tree/vmpal-v7.3) |
| Root disk | Alpine Linux 3.24.2 (aarch64): 44 packages from 30 origins, 22 of them copyleft ([packages.tsv](packages.tsv)) |
| BusyBox | Alpine's busybox 1.37.0-r31 (`/bin/busybox` and `/bin/busybox.static`): [huyphams/busybox, tag vmpal-1.37.0-r31](https://github.com/huyphams/busybox/tree/vmpal-1.37.0-r31) |
| BuildKit | `/usr/bin/buildkitd` and `/usr/bin/buildctl`: [v0.34.0](https://github.com/moby/buildkit/tree/v0.34.0) (commit f5b59a1f2fb25a0cb7072c398cab9aed7835da4e) |
| Release | [vm-2](https://github.com/huyphams/vmpal-linux-for-containers/releases/tag/vm-2): 22 source tars and 6 Go module zips, 153,613,730 bytes with SHA256SUMS |

## How it was built

- The kernel: [build-kernel.sh](build-kernel.sh), on 2026-10-20 (UTC) in an `ubuntu:26.04` container (gcc 15.2.0, GNU ld
  2.46). It took kernel.org's `linux-7.3.tar.xz`, checked it against kernel.org's signed `sha256sums.asc`, started
  from Apple's Containerization `config-arm64`, and turned on the options Docker needs and two for hardening. The
  configuration it ended with is `VMPal/config-arm64` in the fork, the same file as the one in the kernel
  (`/proc/config.gz`).
- The root disk: [build-root.sh](build-root.sh) with `ROOT_ONLY=1`, on 2026-10-20 (UTC) in an `alpine:3.24` container.
  It took Alpine 3.24.2's minimal root (checked against Alpine's SHA-256), ran `apk update`, `apk upgrade` and `apk
  add crun iptables ip6tables iproute2-minimal socat e2fsprogs tar zstd busybox-static tini-static`, compiled
  vagent and vroot, and added buildkitd, buildctl and the build bridge.
- BuildKit: built on a Mac with Go 1.26.10 from a clone of its signed tag v0.34.0, with its `vendor/`, CGO off, and
  for buildkitd the build tags `osusergo netgo static_build seccomp`. Both programs record the tag's commit, with no
  local changes. They link five MPL-2.0 modules (github.com/cyphar/filepath-securejoin v0.7.0, whose pathrs-lite is
  MPL-2.0; github.com/hashicorp/go-cleanhttp v0.5.2, go-immutable-radix/v2 v2.1.0, go-retryablehttp v0.7.8 and
  golang-lru/v2 v2.0.7) and github.com/spdx/tools-golang v0.5.7. Their zips are in the release; each one's h1 hash
  matches sum.golang.org and BuildKit's go.sum ([go-modules.tsv](go-modules.tsv)).

## Files no package installed

[unpackaged.tsv](unpackaged.tsv) lists them:
- `/sbin/vagent`, `/sbin/vroot` and `/usr/bin/buildbridge`: VMPal's own (see the [README](../README.md#licenses)).
- `/usr/bin/buildkitd` and `/usr/bin/buildctl`: BuildKit, above.
- `/etc/resolv.conf` and `/var/log/apk.log`: written by the build.
