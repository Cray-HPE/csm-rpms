#!/usr/bin/env bash

function usage() {
    echo >&2 "usage: ${0##*/} OUTPUT-FILE REPOS-FILE... "
    exit 1
}

[[ $# -ge 2 ]] || usage
outfile="$1"
shift

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

set -o errexit
set -o pipefail
set -o xtrace

# Temporary directory to cache working files
workdir="$(mktemp -d)"

function cleanup() {
    [[ -v cid ]] && docker rm -f "$cid"
    [[ -v image ]] && docker rmi -f "$image"
    [[ -d "$workdir" ]] && rm -fr "$workdir"
}

trap cleanup EXIT

cat "$@" \
| docker run -i \
    --cidfile "${workdir}/container-id" \
    -v "$(realpath "$ROOTDIR"):/data" \
    arti.dev.cray.com/baseos-docker-master-local/sles15sp2:latest \
    bash -c "set -exo pipefail
    {
        zypper --non-interactive install  --auto-agree-with-licenses gawk
        source /data/scripts/rpm-functions.sh
        cleanup-all-repos
    } </dev/null
    zypper-add-repos"

cid="$(cat "${workdir}/container-id")"
image="base-sles15sp2:${cid}"

docker commit "$cid" "$image"
docker rm -f "$cid"

docker run --rm -i \
    -v "$(realpath "$ROOTDIR"):/data" \
    "$image" \
    bash -c "set -exo pipefail
    source /data/scripts/rpm-functions.sh >&2 </dev/null
    remove-comments-and-empty-lines \
    | xargs -r zypper -n --no-refresh download -D" \
| tee "${workdir}/zypper-download.log"

docker rmi -f "$image"

sed -e '/^Warning: Argument resolves to no package: /!d' \
    -e 's/^Warning: Argument resolves to no/ERROR missing/' \
    "${workdir}/zypper-download.log" > "${workdir}/missing-packages.txt"

if [[ -s "${workdir}/missing-packages.txt" ]]; then
    cat >&2 "${workdir}/missing-packages.txt"
    exit 2
fi

# Save zypper log
mv "${workdir}/zypper-download.log" "$outfile"
