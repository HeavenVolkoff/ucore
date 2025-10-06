#!/usr/bin/env bash

set -euo pipefail

. /ctx/log.sh

log "Starting ucore cleanup"

log "Cleaning up package manager cache"
rm -rf /tmp/* 2>/dev/null || true
find /var/* -maxdepth 0 -type d \! -name cache -exec rm -fr {} \; 2>/dev/null
find /var/cache/* -maxdepth 0 -type d \! -name libdnf5 \! -name rpm-ostree -exec rm -fr {} \; 2>/dev/null

log "Committing image state"
ostree container commit
mkdir -p /var/tmp
chmod -R 1777 /var/tmp
