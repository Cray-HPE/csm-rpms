#!/bin/bash
CSM_RPMS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd )"

function add-package-repo() {
  local name="$1"
  local uri="$2"
  local priority="${3:-99}" # Set to 99 (default) and pass verbosely.
  echo "Adding rpm repo ${name} at repo url ${uri}"
  zypper -n addrepo --no-gpgcheck -p ${priority:-99} ${uri} ${name}
  zypper -n --gpg-auto-import-keys refresh ${name}
}

# Adds SUSE Products and Updates repositories; optional URI suffix supports
# Storage repositories
function add-suse-repo() {
  local uri="$1"
  if [[ "$uri" == "${uri%%/*}" ]]; then
    local uri="${uri}/15-SP2"
  fi
  local repo="$(echo "$uri" | tr -s -c '[:alnum:][:cntrl:]' -)"
  add-package-repo "buildonly-suse-${repo}-Pool"    "https://arti.dev.cray.com/artifactory/mirror-SUSE/Products/${uri}/x86_64/product/"
  add-package-repo "buildonly-suse-${repo}-Updates" "https://arti.dev.cray.com/artifactory/mirror-SUSE/Updates/${uri}/x86_64/update/"
}

# Adds Cray repositories for specified architectures
function add-cray-repo() {
  local uri="$1"
  local ref="$2"
  local name="$(echo "$uri" | tr -s -c '[:alnum:][:cntrl:]' -)"
  shift 2
  for arch in "$@"; do
    # Uses CAR CI build repositories instead of bloblets to guarantee latest
    # RPMs are available.
    add-package-repo "buildonly-cray-${name}-sle-15sp2-${arch}" "http://car.dev.cray.com/artifactory/${uri}/sle15_sp2_ncn/${arch}/${ref}/" "${priority:-89}"
  done
}

# Read repos from manifest files and add to repos accordingly
function add-package-repos() {
  sed '/^[a-zA-Z].*$/!d' ${CSM_RPMS_DIR}/repos/package.repos | while read -r line; do
    add-package-repo $line
  done
}

function add-suse-repos() {
  sed '/^[a-zA-Z].*$/!d' ${CSM_RPMS_DIR}/repos/suse.repos | while read -r line; do
    add-suse-repo $line
  done
}

function add-cray-repos() {
  sed '/^[a-zA-Z].*$/!d' ${CSM_RPMS_DIR}/repos/cray.repos | while read -r line; do
    add-cray-repo $line
  done
}

function setup-package-repos() {
  add-suse-repos
  add-package-repos
  add-cray-repos

  zypper lr -e /tmp/repos.repos
  cat /tmp/repos.repos
}

function install-packages() {
  local packages_path="$1"
  zypper -n install --auto-agree-with-licenses --no-recommends $(sed '/^[a-zA-Z].*$/!d' $packages_path)
}

function get-current-package-list() {
  local inventory_file=$(mktemp)
  local output_path="$1"
  local packages="$2"
  local base_inventory="$3"

  if [[ ! -z "$base_inventory" ]]; then
    local base_arg="-b $base_inventory"
  else
    local base_arg=""
  fi

  python3 ${CSM_RPMS_DIR}/scripts/get-packages.py -p /tmp -f $(basename $inventory_file) $base_arg
  get-package-list-from-inventory $inventory_file $output_path $packages
}

function get-package-list-from-inventory() {
  local inventory_file="$1"
  local output_path="$2"
  local packages="$3"

  if [[ "$packages" == "explicit" ]]; then
    local jq_script='. | map(select(.status=="i+")) | map("\(.name)=\(.version)") | unique | .[]'
  elif [[ "$packages" == "deps" ]]; then
    local jq_script='. | map(select(.status=="i")) | map("\(.name)=\(.version)") | unique | .[]'
  else
    local jq_script='. | map("\(.name)=\(.version)") | unique | .[]'
  fi

  cat $inventory_file | jq -r "${jq_script}" > $output_path
}

function cleanup-package-repos() {
  echo "Cleaning up buildonly-* package repos"
  for repo in $(zypper lr | awk -F' | ' '{print $3}' | grep ^buildonly); do
    echo "Removing package repo ${repo}"
    zypper -n removerepo ${repo} || true
  done
  echo "Running a zypper clean"
  zypper -n clean --all
  echo "Unmounting and removing any mounted artifacts, if present"
  umount /mnt/shasta-cd-repo &>/dev/null || true
  rm -rf /mnt/shasta-cd-repo &>/dev/null || true
}

function cleanup-all-repos() {
  echo "Cleaning up all repos"
  # Remove all repos since everything is configured at this point
  zypper -n removerepo -a
  echo "Running a zypper clean"
  zypper -n clean --all
}
