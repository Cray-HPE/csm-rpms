#!/bin/bash

CSM_RPMS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd )"

function list-suse-repos-files() {
  cat <<EOF
${CSM_RPMS_DIR}/repos/suse.repos
EOF
}

function list-hpe-spp-repos-files() {
  cat <<EOF
${CSM_RPMS_DIR}/repos/hpe-spp.repos
EOF
}

function list-cray-repos-files() {
  cat <<EOF
${CSM_RPMS_DIR}/repos/cray.repos
${CSM_RPMS_DIR}/repos/cray-metal.repos
EOF
}

function list-cray-compute-repos-files() {
  cat <<EOF
${CSM_RPMS_DIR}/repos/cray-compute.repos
EOF
}

function remove-comments-and-empty-lines() {
  sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "$@"
}

function zypper-add-repos() {
  remove-comments-and-empty-lines \
  | awk '{ NF-=1; print }' \
  | while read url name flags; do
    local alias="buildonly-${name}"
    echo "Adding repo ${alias} at ${url}"
    zypper -n addrepo $flags "${url}" "${alias}"
    zypper -n --gpg-auto-import-keys refresh "${alias}"
  done
}

function add-hpe-spp-repos() {
  list-hpe-spp-repos-files | xargs -r cat | zypper-add-repos
}

function add-suse-repos() {
  list-suse-repos-files | xargs -r cat | zypper-add-repos
}

function add-cray-repos() {
  list-cray-repos-files | xargs -r cat | zypper-add-repos
}

function add-cray-compute-repos() {
  list-cray-compute-repos-files | xargs -r cat | zypper-add-repos
}

function setup-package-repos() {
  case "$1" in
  -c|--compute)
    add-cray-compute-repos
    ;;
  *)
    add-suse-repos
    add-hpe-spp-repos
    add-cray-repos
    ;;
  esac

  zypper lr -e /tmp/repos.repos
  cat /tmp/repos.repos
}

function list-packages-files() {
  find "${CSM_RPMS_DIR}/packages" \( -name '*.packages' ! -name 'compute-*.packages' \)
}

function list-packages() {
  list-package-files | xargs -r cat | remove-comments-and-empty-lines
}

function list-compute-packages-files() {
  find "${CSM_RPMS_DIR}/packages" -name 'compute-*.packages'
}

function list-compute-packages() {
  list-compute-package-files | xargs -r cat | remove-comments-and-empty-lines
}

function install-packages() {
  if [[ "$DEV" = 'true' ]]; then
    remove-comments-and-empty-lines "$1" | xargs -t -r zypper -n install --auto-agree-with-licenses --no-recommends --allow-unsigned-rpm
  else
    remove-comments-and-empty-lines "$1" | xargs -t -r zypper -n install --auto-agree-with-licenses --no-recommends
  fi
}

function update-package-versions() {
  local packages_path="$1"
  local repos_filter="$2"
  local output_diffs_only="$3"
  local auto_yes="$4"
  local filter="$5"

  if [[ ! -z "$filter" ]]; then
    echo "Filtering packages with regex $filter"
  fi

  local package_names=""

  # Filter out just the package names we want
  while read -r package; do
    local parts=(${package//=/ })
    local package=${parts[0]}
    local version=${parts[1]}

    if [[ ! -z "$filter" && ! $package =~ $filter ]]; then
      continue
    fi

    package_names="${package_names} $package"
  done < <(sed '/^[a-zA-Z].*$/!d' $packages_path)


  echo "Looking up latest versions"

  if [[ "$repos_filter" != "all" ]]; then
    local repos=$(zypper lr | grep "${repos_filter}" | awk '{printf " -r %s", $1}')
    echo "Filtering repos matching grep pattern ${repos_filter}"
    if [[ -z "$repos" ]]; then
      echo "Error: No repos matched filter"
      exit 1
    fi
  else
    local repos=""
  fi

  local package_info=$(zypper --no-refresh info $repos $package_names)

  for package in $package_names; do
    local current_version=$(cat $packages_path | grep -oP "^${package}=\K.*$")
    local latest_version=$(echo "${package_info}" | grep -oPz "Name + : ${package}\nVersion + : \K.*" | tr '\0' '\n')
    local repo=$(echo "${package_info}" | grep -oPz "Repository + : .*\nName + : ${package}\n" | grep -oPz "Repository + : \K.*" | tr '\0' '\n')

    if [[ "$current_version" != "$latest_version" || $output_diffs_only != "true" ]]; then
      echo
      echo "Package:         $package"
      if [[ "$latest_version" == "" ]]; then
        echo "                 Couldn't find '$package' in current repo list. Skipping"
        continue
      fi
      echo "Repository:      $repo"
      echo "Current version: $current_version"
      echo "Latest version:  $latest_version"
    fi

    if [[ "$current_version" != "$latest_version" && $output_diffs_only != "true" ]]; then
      if [[ "$auto_yes" != "true" ]]; then
        read -p "Update package lock version (y/N)?" answer
      fi
      if [[ "$auto_yes" == "true" || "$answer" == "y" ]]; then
        update-package-version $packages_path $package $latest_version
        echo "Packages file updated"
      fi
    elif [[ $output_diffs_only != "true" ]]; then
      echo "Version already up to date"
    fi

  done
}

function update-package-version() {
  local packages_path="$1"
  local package="$2"
  local new_version="$3"

  sed -e "s/$package=.*/$package=$new_version/g" -i "$packages_path"
}

function validate-package-versions() {
  local packages_path="$1"

  echo "Running zypper install --dry-run to validate packages"
  zypper --no-refresh --non-interactive install --dry-run --auto-agree-with-licenses --no-recommends --force-resolution $(sed '/^[a-zA-Z].*$/!d' $packages_path)
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
  echo "Disabling remote zypper service repos"
  zypper ms --remote --disable
}
