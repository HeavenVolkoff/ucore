#!/usr/bin/env bash

set -euo pipefail

. log.sh

# install packages.json stuffs
export IMAGE_NAME=ucore-hci
log "Installing regular packages for ${IMAGE_NAME}"
/ctx/packages.sh

log "Tweak os-release"
sed -i '/^PRETTY_NAME/s/(uCore.*$/(uCore HCI)"/' /usr/lib/os-release
