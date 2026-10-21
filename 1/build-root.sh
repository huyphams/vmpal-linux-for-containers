#!/bin/sh
# Builds the spike's root disk in an Arm64 Linux builder (root, with this folder shared at /media/VMPal/containers):
# Alpine's minimal root with crun, Docker Engine, BuildKit and socat, and vagent as init. Writes out/root.ext4, a blank
# sparse data disk (out/data.img, kept if it's there), and, unless they're there, out/bundles.tar (alpine, nginx and
# postgres unpacked as OCI bundles for crun) and out/images.tar (the same images for Docker Engine).
#   sh build-root.sh [/build]
set -e
here=$(cd "$(dirname "$0")" && pwd)
work=${1:-/build}
# VMPal's engine (ROOT_ONLY) builds with both of these: without them its builds fail.
if [ -n "$ROOT_ONLY" ]; then
    for tool in buildctl buildbridge; do
        [ -f "$here/out/$tool" ] || { echo "out/$tool is missing: build it on the Mac first (see README.md)"; exit 1; }
    done
fi
cd "$work"
release=$(curl -s https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/latest-releases.yaml |
    grep -m1 -E '^ +file: alpine-minirootfs' | awk '{print $2}')
[ -f "$release" ] || curl -sL -o "$release" "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/$release"
rm -rf root && mkdir root && tar xzf "$release" -C root
cp /etc/resolv.conf root/etc/
chroot root /bin/sh -c 'apk update -q && apk add -q crun docker buildkit iptables ip6tables iproute2-minimal socat e2fsprogs tar zstd tini build-base linux-headers'
cp "$here/agent/vagent.c" root/tmp/
chroot root /bin/sh -c 'gcc -O2 -static -o /sbin/vagent /tmp/vagent.c && strip /sbin/vagent'
chroot root /bin/sh -c 'apk del -q build-base linux-headers && rm -rf /var/cache/apk/* /tmp/vagent.c'
# Apple's NAT until udhcpc writes the VM's own (the builder's, with its 127.0.0.53, means nothing in the VM).
echo 'nameserver 192.168.64.1' > root/etc/resolv.conf
# buildctl, for the engine's `POST /build` (Alpine's buildkit has only the daemon): out/buildctl, built on the Mac
# from BuildKit's source (see README.md). The build bridge, for the docker CLI's default builder (POST /grpc and
# /session): out/buildbridge, built on the Mac by build-bridge.sh.
for tool in buildctl buildbridge; do
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
