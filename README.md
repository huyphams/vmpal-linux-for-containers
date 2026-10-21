# Linux for containers: source code

[VMPal](https://vmpal.com) runs Linux containers on a Mac in a small virtual machine of its own, Linux for
containers: an Arm64 Linux kernel from kernel.org, built with VMPal's configuration, and a root disk of Alpine Linux
packages, BuildKit and VMPal's agent. VMPal downloads it from files.vmpal.com, and its container engine boots it with
Apple's Virtualization framework. This repository has the source code of its GPL and other copyleft parts, for every
version VMPal has shipped, and how each version was built.

## Versions

### Linux for containers 2

| | |
|---|---|
| Downloaded by | VMPal 0.90 and later |
| Archive | [files.vmpal.com/containers/2/vm.aar](https://files.vmpal.com/containers/2/vm.aar), SHA-256 `53095b4af9b60a76d9d7a10e7a98fa29a6756b5b0d3d66a0f35d729a169bf964` |
| Kernel | Linux 7.3: [huyphams/linux, tag vmpal-v7.3](https://github.com/huyphams/linux/tree/vmpal-v7.3) |
| BusyBox | Alpine's busybox 1.37.0-r31: [huyphams/busybox, tag vmpal-1.37.0-r31](https://github.com/huyphams/busybox/tree/vmpal-1.37.0-r31) |
| Other packages | [2/packages.tsv](2/packages.tsv); their source in release [vm-2](https://github.com/huyphams/vmpal-linux-for-containers/releases/tag/vm-2) |
| BuildKit | [v0.34.0](https://github.com/moby/buildkit/tree/v0.34.0); the MPL-2.0 modules it links in release [vm-2](https://github.com/huyphams/vmpal-linux-for-containers/releases/tag/vm-2) |
| Details | [2/README.md](2/README.md) |

### Linux for containers 1

| | |
|---|---|
| Downloaded by | VMPal 0.87, 0.88 and 0.89 |
| Archive | [files.vmpal.com/containers/1/vm.aar](https://files.vmpal.com/containers/1/vm.aar), SHA-256 `531a11a136cf94682c898c3614a7dd9f7f854b778359dff12a3b8795e0312016` |
| Kernel | Linux 7.2.11: [huyphams/linux, tag vmpal-v7.2.11](https://github.com/huyphams/linux/tree/vmpal-v7.2.11) |
| BusyBox | Alpine's busybox 1.37.0-r31: [huyphams/busybox, tag vmpal-1.37.0-r31](https://github.com/huyphams/busybox/tree/vmpal-1.37.0-r31) |
| Other packages | [1/packages.tsv](1/packages.tsv); their source in release [vm-1](https://github.com/huyphams/vmpal-linux-for-containers/releases/tag/vm-1) |
| BuildKit | buildctl [v0.33.1](https://github.com/moby/buildkit/tree/v0.33.1); the MPL-2.0 modules it links in release [vm-1](https://github.com/huyphams/vmpal-linux-for-containers/releases/tag/vm-1) |
| Details | [1/README.md](1/README.md) |

## What each version's folder has

- `README.md`: how that version was built, and what's particular to it.
- `packages.tsv`: every Alpine package in the root disk, with its version, origin (the aports folder Alpine builds it
  from), license, whether it's copyleft, the aports commit Alpine built it from, and where its source is.
- `aports/`: the aports folder of each copyleft origin at that commit: its APKBUILD and Alpine's patches and files.
- `distfiles.tsv`: every file those APKBUILDs download, with the SHA-512 the APKBUILD gives, where we fetched it
  (Alpine's distfiles mirror) and its upstream URL.
- `go-modules.tsv`: the Go modules of the programs no package installs (BuildKit and VMPal's build bridge), with
  their licenses and h1 hashes.
- `unpackaged.tsv`: every file in the root disk that no package installed.
- `build-kernel.sh`, `build-root.sh`: VMPal's scripts that built that version.
- `vm.txt`: the SHA-256 of the archive and its two files, the kernel's version string, the Alpine release.
- `SHA256SUMS`: the SHA-256 of each file in that version's release.

Each release, `vm-<n>`, has one `<origin>-<pkgver>-r<pkgrel>-source.tar` per copyleft origin, holding its aports
folder (`aports/<main|community>/<origin>/`), every file its APKBUILD downloads (`distfiles/`) and `distfiles.tsv`.
To build a package the way Alpine did, run Alpine's `abuild` in its aports folder on Alpine 3.24, with `SRCDEST` set
to the `distfiles` folder. The release also has `gomod-<module>-<version>.zip` for each copyleft Go module, the exact
zip proxy.golang.org serves.

## Checking a source against the VM

1. Download the archive and check its SHA-256 against the table above: `shasum -a 256 vm.aar`.
2. Unpack it on a Mac: `aa extract -i vm.aar -d vm` gives `vm/Image` (the kernel) and `vm/root.ext4` (the root disk).
3. List its packages with e2fsprogs' debugfs, which opens the disk read-only: `debugfs -R 'cat /lib/apk/db/installed'
   vm/root.ext4`. Each package's `P:` (name), `V:` (version), `o:` (origin) and `c:` (aports commit) are what
   `packages.tsv` lists.
4. The aports folder at that commit is in `<n>/aports/`, and on Alpine's GitLab at
   `https://gitlab.alpinelinux.org/alpine/aports/-/tree/<commit>/<main|community>/<origin>`. Its APKBUILD's
   `sha512sums` covers every source file. To check a release's tar against it:

   ```sh
   tar xf busybox-1.37.0-r31-source.tar && cd busybox-1.37.0-r31
   cp distfiles/* aports/main/busybox/ && cd aports/main/busybox
   sed -n '/^sha512sums="/,/^"/p' APKBUILD | sed '1d;$d' | shasum -a 512 -c
   ```

5. The kernel: `strings vm/Image | grep 'Linux version'` gives its version. Its configuration is embedded:
   `scripts/extract-ikconfig vm/Image`, run in a Linux source tree, prints the same file as `VMPal/config-arm64` at
   the fork's tag.
6. A Go program: `debugfs -R 'dump /usr/bin/buildkitd buildkitd' vm/root.ext4`, then `go version -m buildkitd`
   lists the modules it links. `go mod download -json <module>@<version>` gives the h1 hash `go-modules.tsv` lists.

## Licenses

Each package and module keeps its own license; `packages.tsv` and `go-modules.tsv` list them. Linux and BusyBox are
under the GPL-2.0. The files from Alpine's aports are Alpine's. Nothing here changes any of these licenses.

Some sources here go beyond what the licenses ask for:
- Packages with a permissive choice (libcap and zstd: BSD-3-Clause or GPL), and gcc's libgcc and libstdc++, which the
  GCC Runtime Library Exception covers.
- Alpine's docker, containerd, runc, buildkit and docker-cli-buildx (version 1 only): Apache-2.0 themselves, but they
  link MPL-2.0 Go modules, which their tarballs carry in `vendor/`.
- github.com/spdx/tools-golang, Apache-2.0 or GPL-2.0-or-later, linked by BuildKit 0.34.0.

VMPal's own programs in the root disk are not published here: `/sbin/vagent` (the VM's init and agent), `/sbin/vroot`
(version 2 on) and `/usr/bin/buildbridge` (the build bridge). vagent and vroot are C, statically linked with musl
(MIT) and libgcc (GCC Runtime Library Exception). The build bridge is Go without C; it links golang.org/x/net,
golang.org/x/sys, golang.org/x/text and google.golang.org/protobuf (BSD-3-Clause), and google.golang.org/grpc and
google.golang.org/genproto/googleapis/rpc (Apache-2.0).

BuildKit's buildkitd and buildctl are Apache-2.0. VMPal builds them from BuildKit's release tags, linked above.

## Something missing?

If you need the source of anything in Linux for containers that isn't here, or a file doesn't match, open an issue in
this repository. Say which version and which file or package, and we'll add its source here.
