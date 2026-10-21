#!/bin/sh
# Builds the container VM's root disk in an Arm64 Linux builder (root, with this folder shared at
# /media/VMPal/containers; Ubuntu or Alpine, or such a container on a dev engine): Alpine's newest minimal root, checked
# against Alpine's checksum and brought up to date, with crun, socat, BusyBox's static build and tini's, vagent as init
# and vroot (agent/), and BuildKit and the build bridge built on the Mac (see README.md). Writes out/root.ext4, a blank
# sparse data disk (out/data.img, kept if it's there), and, unless they're there, out/bundles.tar (alpine, nginx and
# postgres unpacked as OCI bundles for crun) and out/images.tar (the same images for Docker Engine). The spike's root
# (not ROOT_ONLY) has Docker Engine too, for its docker mode; VMPal's engine runs none of it.
#   sh build-root.sh [/build]
set -e
here=$(cd "$(dirname "$0")" && pwd)
work=${1:-/build}
# VMPal's engine (ROOT_ONLY) builds with these: without them its builds fail.
if [ -n "$ROOT_ONLY" ]; then
    for tool in buildkitd buildctl buildbridge; do
        [ -f "$here/out/$tool" ] || { echo "out/$tool is missing: build it on the Mac first (see README.md)"; exit 1; }
    done
fi
cd "$work"
releases=https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64
curl -sf -o latest-releases.yaml "$releases/latest-releases.yaml"
release=$(grep -m1 -E '^ +file: alpine-minirootfs' latest-releases.yaml | awk '{print $2}')
sha=$(awk -v f="$release" '$1 == "file:" { found = ($2 == f) } found && $1 == "sha256:" { print $2; exit }' latest-releases.yaml)
[ -f "$release" ] || curl -sfL -o "$release" "$releases/$release"
echo "$sha  $release" | sha256sum -c - || exit 1
rm -rf root && mkdir root && tar xzf "$release" -C root
cp /etc/resolv.conf root/etc/
# What the minimal root has, brought up to date first (it's as old as the release), then what the VM needs.
docker=; [ -n "$ROOT_ONLY" ] || docker=docker
chroot root /bin/sh -c "apk update -q && apk upgrade -q && apk add -q crun iptables ip6tables iproute2-minimal socat e2fsprogs tar zstd busybox-static tini-static $docker build-base linux-headers"
cp "$here/agent/vagent.c" "$here/agent/vroot.c" root/tmp/
chroot root /bin/sh -c 'gcc -O2 -static -o /sbin/vagent /tmp/vagent.c && gcc -O2 -static -o /sbin/vroot /tmp/vroot.c && strip /sbin/vagent /sbin/vroot'
chroot root /bin/sh -c 'apk del -q build-base linux-headers && rm -rf /var/cache/apk/* /tmp/vagent.c /tmp/vroot.c'
# vroot runs BusyBox in containers' files: it must be the static one (a dynamic one would load the container's libc).
grep -q ld-musl root/bin/busybox.static && { echo "root/bin/busybox.static isn't static"; exit 1; }
# Apple's NAT until udhcpc writes the VM's own (the builder's, with its 127.0.0.53, means nothing in the VM).
echo 'nameserver 192.168.64.1' > root/etc/resolv.conf
# BuildKit's buildkitd, and buildctl for the engine's `POST /build`: out/buildkitd and out/buildctl, built on the Mac
# from BuildKit's source (see README.md; Alpine's is older and lacks fixes). The build bridge, for the docker CLI's
# default builder (POST /grpc and /session): out/buildbridge, built on the Mac by build-bridge.sh.
for tool in buildkitd buildctl buildbridge; do
    if [ -f "$here/out/$tool" ]; then install -m 0755 "$here/out/$tool" "root/usr/bin/$tool"
    else echo "warning: out/$tool is missing, so this root disk has none"; fi
done
echo "root: $(du -sh root | cut -f1); vagent: $(stat -c %s root/sbin/vagent) bytes"
rm -f "$here/out/root.ext4"
truncate -s 1G "$here/out/root.ext4"
mkfs.ext4 -q -F -L root -d root "$here/out/root.ext4"
# ROOT_ONLY=1: just the root disk, as VMPal's engine needs (it pulls images itself).
[ -n "$ROOT_ONLY" ] && { ls -la "$here/out/root.ext4"; exit 0; }
[ -f "$here/out/data.img" ] || truncate -s 16G "$here/out/data.img"
[ -f "$here/out/bundles.tar" ] && [ -f "$here/out/images.tar" ] && { ls -la "$here/out"; exit 0; }

# Containers for crun: each image's files as a bundle's rootfs, with crun's default config.json.
rm -rf bundles && mkdir bundles
for image in alpine nginx:alpine postgres:alpine; do
    name=${image%%:*}
    docker pull -q "$image" >/dev/null
    id=$(docker create "$image")
    mkdir -p "bundles/$name/rootfs"
    docker export "$id" | tar x -C "bundles/$name/rootfs"
    docker rm "$id" >/dev/null
    docker image inspect "$image" --format '{{json .Config}}' >"bundles/$name/image-config.json"
done
tar cf "$here/out/bundles.tar" bundles
# The same images for Docker Engine, to load without a network.
docker save alpine nginx:alpine postgres:alpine -o "$here/out/images.tar"
ls -la "$here/out"
