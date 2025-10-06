#!/usr/bin/env bash

set -oue pipefail

# install packages.json stuffs
export IMAGE_NAME=ucore-hci
echo "Installing regular packages for ${IMAGE_NAME}"
/ctx/packages.sh

echo "Tweak os-release"
sed -i '/^PRETTY_NAME/s/(uCore.*$/(uCore HCI)"/' /usr/lib/os-release
