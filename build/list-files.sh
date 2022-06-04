#!/usr/bin/env bash

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/scripts/rpm-functions.sh"

function usage() {
    echo >&2 "usage: ${0##*/} [compute-](repo|pkgs) ..."
    exit 1
}

[[ $# -gt 0 ]] || usage

set -o errexit
set -o pipefail

while [[ $# -gt 0 ]]; do
    case "$1" in
    repos|repositories)
        list-google-repos-files
        list-hpe-spp-repos-files
        list-cray-repos-files
        list-suse-repos-files
        ;;
    pkgs|packages)
        list-packages-files
        ;;
    compute-pkgs|compute-packages)
        list-compute-packages-files
        ;;
    esac
    shift
done
