#!/usr/bin/env bash

set -euo pipefail

. /ctx/log.sh

log "Starting ucore-minimal installation"

ARCH="$(rpm -E '%{_arch}')"
RELEASE="$(rpm -E %fedora)"

pushd /tmp/rpms/kernel >/dev/null
KERNEL_VERSION=$(find kernel-*.rpm | grep -P "kernel-(\d+\.\d+\.\d+)-.*\.fc${RELEASE}\.${ARCH}" | sed -E 's/kernel-//' | sed -E 's/\.rpm//')
popd >/dev/null
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(\d+\.\d+\.\d+)' | sed -E 's/kernel-//')"

cat <<EOF
ARCH:             ${ARCH}
RELEASE:          ${RELEASE}
KERNEL_VERSION:   ${KERNEL_VERSION}
QUALIFIED_KERNEL: ${QUALIFIED_KERNEL}
EOF

#### PREPARE

# ALWAYS: disable instalation of weak dependencies
cat <<EOF >>/etc/dnf/dnf.conf
color=always
assumeyes=True
debuglevel=0
rpmverbosity=error
install_weak_deps=False
EOF

log "Enabling ublue-os repos"
dnf -qy install dnf5-plugins
dnf -qy copr enable ublue-os/packages
dnf -qy copr enable ublue-os/ucore

# ALWAYS: disable cisco-open264 repo
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

#### INSTALL

log "List of RPMs in /tmp/rpms/:"
(
    cd /tmp/rpms
    find . -type f -name "*.rpm" | sort
)

log "Installing ucore addons and signing key"
dnf -qy install /tmp/rpms/akmods-common/ublue-os-ucore-addons*.rpm
dnf -qy install ublue-os-signing

# Put the policy file in the correct place and cleanup /usr/etc
cp /usr/etc/containers/policy.json /etc/containers/policy.json
rm -rf /usr/etc

# Handle Kernel Skew with override replace
if [[ "${KERNEL_VERSION}" == "${QUALIFIED_KERNEL}" ]]; then
    log "Installing signed kernel from kernel-cache."
    cd /tmp
    rpm2cpio /tmp/rpms/kernel/kernel-core-*.rpm | cpio -idm
    cp ./lib/modules/*/vmlinuz /usr/lib/modules/*/vmlinuz
    cd /
else
    log "Removing Existing Kernel"
    for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra; do
        if rpm -q $pkg >/dev/null 2>&1; then
            rpm --erase $pkg --nodeps
        fi
    done
    log "Install kernel version ${KERNEL_VERSION} from kernel-cache."
    dnf -qy install \
        /tmp/rpms/kernel/kernel-[0-9]*.rpm \
        /tmp/rpms/kernel/kernel-core-*.rpm \
        /tmp/rpms/kernel/kernel-modules-*.rpm
fi

## ALWAYS: install ZFS (and sanoid deps)
log "Installing ZFS"
dnf -qy install /tmp/rpms/akmods-zfs/kmods/zfs/*.rpm /tmp/rpms/akmods-zfs/kmods/zfs/other/zfs-dracut-*.rpm

log "Generate modules.dep and map files"
# for some reason depmod ran automatically with zfs 2.1 but not with 2.2
depmod -a "${KERNEL_VERSION}"

## ALWAYS: install regular packages

# add tailscale repo
curl --fail --retry 15 --retry-all-errors -sSL -o /etc/yum.repos.d/tailscale.repo \
    https://pkgs.tailscale.com/stable/fedora/tailscale.repo

export IMAGE_NAME=ucore-minimal
log "Installing regular packages for ${IMAGE_NAME}"
/ctx/packages.sh

log "Installing cockpit-sensors from latest github release"
mkdir -p /usr/share/cockpit/sensors
curl --fail --retry 15 --retry-all-errors -sSL \
    "https://github.com/ocristopfer/cockpit-sensors/releases/latest/download/cockpit-sensors.tar.xz" |
    tar -xJf- --strip-components 2 -C /usr/share/cockpit/sensors cockpit-sensors/dist

log "Tweak os-release"
sed -i '/^PRETTY_NAME/s/"$/ (uCore minimal)"/' /usr/lib/os-release
sed -i 's|^VARIANT_ID=.*|VARIANT_ID=ucore|' /usr/lib/os-release
sed -i 's|^VARIANT=.*|VARIANT="uCore"|' /usr/lib/os-release
