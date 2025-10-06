#!/usr/bin/env bash

set -eou pipefail

echo "Starting ucore cleanup"

echo "Cleaning up package manager cache"
rm -rf /tmp/* || true
find /var/* -maxdepth 0 -type d \! -name cache -exec rm -fr {} \;
find /var/cache/* -maxdepth 0 -type d \! -name libdnf5 \! -name rpm-ostree -exec rm -fr {} \;

echo "Committing image state"
ostree container commit
mkdir -p /var/tmp
chmod -R 1777 /var/tmp
