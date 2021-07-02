#!/usr/bin/env bash

function usage() {
    echo >&2 "usage: ${0##*/} INDEX REPOS-FILES"
    exit 1
}

[[ $# -ge 2 ]] || usage
index="$1"
shift

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

set -o errexit
set -o pipefail
set -o xtrace

# Get the list-repos function
source "${ROOTDIR}/scripts/rpm-functions.sh"

# Temporary directory to cache working files
workdir="$(mktemp -d)"
trap "rm -fr '$workdir'" EXIT

# Parse the zypper log and generate an rpm-index
sed -e '/^Not downloading package /!d' \
    -e "s/^Not downloading package '//" \
    -e 's/[[:space:]]\+.*$//' \
| sort -u \
| docker run --rm -i arti.dev.cray.com/internal-docker-stable-local/packaging-tools:0.7.0 rpm-index -v \
    $(cat "$@" | remove-comments-and-empty-lines | awk '{print "-d", $1, $NF}') \
| tee "${workdir}/index.yaml"

mv "${workdir}/index.yaml" "$index"
