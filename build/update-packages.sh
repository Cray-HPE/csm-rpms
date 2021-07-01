#!/usr/bin/env bash


set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

docker rmi -f csm-rpms-cache

find "${ROOTDIR}/packages" ! -name 'compute-node.packages' -name '*.packages' | xargs -n 1 "${ROOTDIR}/scripts/update-package-versions.sh" -y --packages-file
