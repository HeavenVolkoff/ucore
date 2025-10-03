#!/usr/bin/env bash

set -ouex pipefail

ARCH="$(rpm -E '%{_arch}')"
RELEASE="$(rpm -E %fedora)"

pushd /tmp/rpms/kernel
KERNEL_VERSION=$(find kernel-*.rpm | grep -P "kernel-(\d+\.\d+\.\d+)-.*\.fc${RELEASE}\.${ARCH}" | sed -E 's/kernel-//' | sed -E 's/\.rpm//')
popd
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(\d+\.\d+\.\d+)' | sed -E 's/kernel-//')"

#### PREPARE

# enable ublue-os repos
dnf -y install dnf5-plugins
dnf -y copr enable ublue-os/packages
dnf -y copr enable ublue-os/ucore

# always disable cisco-open264 repo
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

#### INSTALL
# inspect to see what RPMS we copied in
find /tmp/rpms/

dnf -y install /tmp/rpms/akmods-common/ublue-os-ucore-addons*.rpm
dnf -y install ublue-os-signing

# Put the policy file in the correct place and cleanup /usr/etc
cp /usr/etc/containers/policy.json /etc/containers/policy.json
rm -rf /usr/etc

# Handle Kernel Skew with override replace
if [[ "${KERNEL_VERSION}" == "${QUALIFIED_KERNEL}" ]]; then
    echo "Installing signed kernel from kernel-cache."
    cd /tmp
    rpm2cpio /tmp/rpms/kernel/kernel-core-*.rpm | cpio -idmv
    cp ./lib/modules/*/vmlinuz /usr/lib/modules/*/vmlinuz
    cd /
else
    # Remove Existing Kernel
    for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra; do
        if rpm -q $pkg >/dev/null 2>&1; then
            rpm --erase $pkg --nodeps
        fi
    done
    echo "Install kernel version ${KERNEL_VERSION} from kernel-cache."
    dnf -y install \
        /tmp/rpms/kernel/kernel-[0-9]*.rpm \
        /tmp/rpms/kernel/kernel-core-*.rpm \
        /tmp/rpms/kernel/kernel-modules-*.rpm
fi

## ALWAYS: install ZFS (and sanoid deps)
dnf -y install /tmp/rpms/akmods-zfs/kmods/zfs/*.rpm /tmp/rpms/akmods-zfs/kmods/zfs/other/zfs-dracut-*.rpm
# for some reason depmod ran automatically with zfs 2.1 but not with 2.2
depmod -a -v "${KERNEL_VERSION}"

## ALWAYS: install regular packages

# add tailscale repo
curl --fail --retry 15 --retry-all-errors -sSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo -o /etc/yum.repos.d/tailscale.repo

# install packages.json stuffs
export IMAGE_NAME=ucore-minimal
/ctx/packages.sh

# tweak os-release
sed -i '/^PRETTY_NAME/s/"$/ (uCore minimal)"/' /usr/lib/os-release
sed -i 's|^VARIANT_ID=.*|VARIANT_ID=ucore|' /usr/lib/os-release
sed -i 's|^VARIANT=.*|VARIANT="uCore"|' /usr/lib/os-release
