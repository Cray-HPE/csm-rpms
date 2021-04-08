#!/bin/bash
CSM_RPMS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd )"

function add-repos() {
  local priority="${2:-99}"
  sed -e 's/#.*$//' -e '/[[:space:]]/!d' "$1" | awk '{print $1, $2}' | while read url name; do
    local alias="buildonly-${name}"
    echo "Adding repo ${alias} at ${url}"
    zypper -n addrepo --no-gpgcheck -p "${priority}" "${url}" "${alias}"
    zypper -n --gpg-auto-import-keys refresh "${alias}"
  done
}

# Read repos from manifest files and add to repos accordingly
function add-hpe-spp-repos() {
  add-repos "${CSM_RPMS_DIR}/repos/hpe-spp.repos" 94
}

function add-suse-repos() {
  add-repos "${CSM_RPMS_DIR}/repos/suse.repos" 99
}

function add-cray-repos() {
  add-repos "${CSM_RPMS_DIR}/repos/cray.repos" 89
}

function setup-package-repos() {
  add-suse-repos
  add-hpe-spp-repos
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
  for repo in $(zypper lr | awk -F'|' '{gsub(/ /,""); print $3}' | grep '^buildonly'); do
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
