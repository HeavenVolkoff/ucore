#!/usr/bin/env bash

set -ouex pipefail

# install packages.json stuffs
export IMAGE_NAME=ucore
/ctx/packages.sh

# cockpit plugin for ZFS management
curl --fail --retry 15 --retry-all-errors -sSL -o /tmp/cockpit-zfs-manager-api.json \
    "https://api.github.com/repos/45Drives/cockpit-zfs-manager/releases/latest"
CZM_TGZ_URL=$(jq -r .tarball_url /tmp/cockpit-zfs-manager-api.json)
curl --fail --retry 15 --retry-all-errors -sSL -o /tmp/cockpit-zfs-manager.tar.gz "${CZM_TGZ_URL}"

mkdir -p /tmp/cockpit-zfs-manager
tar -zxvf /tmp/cockpit-zfs-manager.tar.gz -C /tmp/cockpit-zfs-manager --strip-components=1
mv /tmp/cockpit-zfs-manager/polkit-1/actions/* /usr/share/polkit-1/actions/
mv /tmp/cockpit-zfs-manager/polkit-1/rules.d/* /usr/share/polkit-1/rules.d/
mv /tmp/cockpit-zfs-manager/zfs /usr/share/cockpit

curl --fail --retry 15 --retry-all-errors -sSL -o /tmp/cockpit-zfs-manager-font-fix.sh \
    https://raw.githubusercontent.com/45Drives/scripts/refs/heads/main/cockpit_font_fix/fix-cockpit.sh
chmod +x /tmp/cockpit-zfs-manager-font-fix.sh
/tmp/cockpit-zfs-manager-font-fix.sh

rm -rf /tmp/cockpit-zfs-manager*

mkdir -p /usr/local/bin

# Install starship prompt
curl --fail --retry 15 --retry-all-errors -sSL \
    "https://github.com/starship/starship/releases/latest/download/starship-$(uname -m)-unknown-linux-musl.tar.gz" \
    | tar -xzf - -C /usr/local/bin starship
chmod +x /usr/local/bin/starship

# Install xdg-ninja
mkdir -p /tmp/xdg-ninja
curl --fail --retry 15 --retry-all-errors -sSL \
    https://github.com/b3nj5m1n/xdg-ninja/archive/refs/heads/main.tar.gz \
    | tar -xzf - --strip-components 1 -C /tmp/xdg-ninja

pushd /tmp/xdg-ninja

install -Dm 0755 -T xdg-ninja.sh '/usr/local/bin/xdg-ninja'
install -d '/usr/local/share/xdg-ninja/'
cp -r programs '/usr/local/share/xdg-ninja/'
install -Dm 0644 -t '/usr/local/share/doc/xdg-ninja/' LICENSE README.md
install -Dm 0644 -t '/usr/local/share/man/man1/' man/xdg-ninja.1

popd
rm -rf /tmp/xdg-ninja

# disable tuned service by default
systemctl disable tuned.service

# tweak os-release
sed -i '/^PRETTY_NAME/s/(uCore.*$/(uCore)"/' /usr/lib/os-release
