#!/bin/bash
# Builds the container VM's kernel in an Arm64 Linux builder (root, with this folder shared at /media/VMPal/containers;
# Ubuntu, or an ubuntu container on a dev engine): the newest stable kernel.org release, checked against kernel.org's
# checksums, Apple's Containerization configuration brought up to it, plus the netfilter options Docker's
# check-config.sh asks for and hardening of our own. Writes out/Image and kernel-config-arm64. About 80 s with 12 CPUs.
#   bash build-kernel.sh [/build]
set -e
here=$(cd "$(dirname "$0")" && pwd)
work=${1:-/build}
mkdir -p "$work" && cd "$work"
apt-get update -q >/dev/null
apt-get install -y -q build-essential flex bison bc libssl-dev libelf-dev cpio xz-utils curl jq >/dev/null
version=$(curl -sf https://www.kernel.org/releases.json | jq -r .latest_stable.version)
if [ ! -d "linux-$version" ]; then
    base=https://cdn.kernel.org/pub/linux/kernel/v${version%%.*}.x
    curl -sfL -o "linux-$version.tar.xz" "$base/linux-$version.tar.xz"
    # kernel.org's checksum list (sha256sums.asc, signed by its autosigner) must have the tarball's.
    curl -sfL -o sha256sums.asc "$base/sha256sums.asc"
    grep " linux-$version.tar.xz\$" sha256sums.asc | sha256sum -c -
    tar xJf "linux-$version.tar.xz"
fi
curl -sL -o config-arm64 https://raw.githubusercontent.com/apple/containerization/main/kernel/config-arm64
curl -sL -o check-config.sh https://raw.githubusercontent.com/moby/moby/master/contrib/check-config.sh
cd "linux-$version"
cp ../config-arm64 .config
make olddefconfig >/dev/null
# Docker's iptables tables: on 7.x they need the legacy xtables options too.
for option in NETFILTER_XTABLES_LEGACY IP_NF_IPTABLES_LEGACY IP6_NF_IPTABLES_LEGACY IP_NF_IPTABLES IP_NF_FILTER IP_NF_MANGLE \
    IP_NF_NAT IP_NF_TARGET_MASQUERADE IP_NF_RAW IP_NF_TARGET_REDIRECT IP6_NF_IPTABLES IP6_NF_FILTER IP6_NF_MANGLE \
    IP6_NF_NAT IP6_NF_TARGET_MASQUERADE IP6_NF_RAW NF_TABLES_INET NF_TABLES_IPV4 NF_TABLES_IPV6 NFT_COMPAT NFT_NAT \
    NFT_MASQ NFT_CT NFT_REDIR NETFILTER_XT_MATCH_ADDRTYPE NETFILTER_XT_MATCH_CONNTRACK NETFILTER_XT_TARGET_MASQUERADE \
    NETFILTER_XT_NAT NETFILTER_XT_MARK BRIDGE_NETFILTER BRIDGE_VLAN_FILTERING LRU_GEN LRU_GEN_ENABLED VIRTIO_BALLOON \
    PAGE_REPORTING; do
    scripts/config -e $option
done
# Hardening, as Apple's x86-64 configuration has it (containers run as root in the VM): no BPF for unprivileged
# programs, and bounds checks on copies between the kernel and programs.
for option in BPF_UNPRIV_DEFAULT_OFF HARDENED_USERCOPY; do
    scripts/config -e $option
done
make olddefconfig >/dev/null
echo "Docker's check-config.sh, what's still missing (optional ones left out):"
bash ../check-config.sh .config 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep missing |
    grep -v -E 'SELINUX|APPARMOR|BTRFS|zfs|zpool|IPVS|IP_VS|FTP|TFTP|DUMMY|ESP|GHASH' || echo "  nothing"
for option in BPF_UNPRIV_DEFAULT_OFF HARDENED_USERCOPY NETFILTER_XTABLES_LEGACY; do
    grep -q "^CONFIG_$option=y" .config || { echo "CONFIG_$option didn't stay on"; exit 1; }
done
make -j"$(nproc)" Image >"$work/kbuild.log" 2>&1
cp arch/arm64/boot/Image "$here/out/Image"
cp .config "$here/kernel-config-arm64"
echo "Linux $version: $(stat -c %s arch/arm64/boot/Image) bytes"
