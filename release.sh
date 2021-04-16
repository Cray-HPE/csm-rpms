#!/usr/bin/env bash


set -exo pipefail

: "${RELEASE:="${RELEASE_NAME:="csm-rpms"}-${RELEASE_VERSION:="0.0.0"}"}"

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/vendor/stash.us.cray.com/scm/shastarelm/release/lib/release.sh"

BUILDDIR="${1:-"$(realpath -m "$ROOTDIR/dist/${RELEASE}")"}"

# Initialize build directory
[[ -d "$BUILDDIR" ]] && rm -fr "$BUILDDIR"
mkdir -p "$BUILDDIR"

# Sync RPM manifests
rpm-sync "${ROOTDIR}/index/sle-15sp2.yaml" "${BUILDDIR}/sle-15sp2"
rpm-sync "${ROOTDIR}/index/sle-15sp2-compute.yaml" "${BUILDDIR}/sle-15sp2-compute"

# Fix-up cray directories by removing misc subdirectories
{
    find "${BUILDDIR}/" -name '*-team' -type d
    find "${BUILDDIR}/" -name 'github' -type d
} | while read path; do
    mv "$path"/* "$(dirname "$path")/"
    rmdir "$path"
done

# Remove empty directories
find "${BUILDDIR}/" -empty -type d -delete

# Create CSM repositories
createrepo "${BUILDDIR}/sle-15sp2"
createrepo "${BUILDDIR}/sle-15sp2-compute"

# Package the distribution into an archive
tar -C "${BUILDDIR}/.." -cvzf "${BUILDDIR}/../$(basename "$BUILDDIR").tar.gz" "$(basename "$BUILDDIR")/" --remove-files
