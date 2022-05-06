#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

# Update non-compute-node packages
docker rmi -f csm-rpms-cache
#shellcheck disable=SC2038
find "${ROOTDIR}/packages" ! -name 'compute-node.packages' -name '*.packages' | xargs -n 1 "${ROOTDIR}/scripts/update-package-versions.sh" -y --packages-file

# Update compute-node packages
docker rmi -f csm-rpms-cache-compute
"${ROOTDIR}/scripts/update-package-versions.sh" --compute -y --packages-file "${ROOTDIR}/packages/compute-node.packages"
