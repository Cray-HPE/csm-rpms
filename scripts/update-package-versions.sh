#!/usr/bin/env bash
set -ex

realpath() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

function usage(){
    cat <<EOF
Usage:

    update-package-versions.sh

    Loops through the packages in the given packages-file path and compares the packages locked version to the latest found version the defined repos.
    One by one, if an update is found the script prompts if the version should be updated in the packages file.
    If you choose to update the version then the given packages-file is updated directly.
    You can then git commit to the appropriate branch and create a PR.

    -p|--packages-file <path>  Required: The packages file path to update versions in (eg packages/node-image-non-compute-common/base.packages)

    [-f|--filter <pattern>]    Package regex pattern to filter against. Only packages matching the filter will be queried and prompted to update. (eg cray-)
    [-r|--repos <pattern>]     Repo regex pattern to filter against. Latest version will only be looked up in repos names matching the filter. (eg SUSE)
    [-o|--output-diffs-only]   The package information, including the latest found version, will be outputted instead of prompting to update the package file directly
    [-y|--yes]                 No prompts, instead auto updates the package file with any new version that matches other option filters
    [--validate]               Validate that packages exist instead looking for newer versions
    [--no-cache]               Destroy the docker image used as a cache so we do not have to re-add repos on every usage
    [--suffix <string>]        Suffix to add to the end of the docker image and container so this can be run in parallel in CI
    [--refresh]                Do a zypper refresh before querying for latest versions
    [--help]                   Prints this usage and exists

    Examples

    ./scripts/update-package-versions.sh -p packages/node-image-non-compute-common/base.packages
    --------------
    Query all packages in base.packages and prompt the user to update the version if a newer version is found in the repos one by one.


    ./scripts/update-package-versions.sh -p packages/node-image-non-compute-common/base.packages -f '^cray' -o
    --------------
    Query packages in base.packages that start with 'cray'. Only print out packages that have a different version found


    ./scripts/update-package-versions.sh -p packages/node-image-non-compute-common/base.packages -f cray-network-config -r shasta-1.4
    --------------
    Only update the package cray-network-config in a repo that contains the shasta-1.4 name


    ./scripts/update-package-versions.sh -p packages/node-image-non-compute-common/base.packages -r buildonly-SUSE
    --------------
    Only update packages found in the upstream SUSE repos

    ./scripts/update-package-versions.sh -p packages/node-image-non-compute-common/base.packages -r buildonly-SUSE -y
    --------------
    Same as the last example, but automatically update all SUSE packages rather than prompt one by one

EOF
}

SOURCE_DIR="$(dirname $0)/.."
SOURCE_DIR="$(pushd "$SOURCE_DIR" > /dev/null && pwd && popd > /dev/null)"

OUTPUT_DIFFS_ONLY="false"
REPOS_FILTER="all"
AUTO_YES="false"

DOCKER_CACHE_IMAGE="csm-rpms-cache"
DOCKER_BASE_IMAGE="arti.dev.cray.com/baseos-docker-master-local/sles15sp3:latest"

while [[ "$#" -gt 0 ]]
do
  case $1 in
    -h|--help)
      usage
      exit
      ;;
    -p|--packages-file)
      PACKAGES_FILE="$2"
      ;;
    -f|--filter)
      FILTER="$2"
      ;;
    -r|--repos)
      REPOS_FILTER="$2"
      ;;
    -c|--compute)
      DOCKER_CACHE_IMAGE="${DOCKER_CACHE_IMAGE}-compute"
      ;;
    -o|--output-diffs-only)
      OUTPUT_DIFFS_ONLY="true"
      ;;
    -y|--yes)
      AUTO_YES="true"
      ;;
    --validate)
      VALIDATE="true"
      ;;
    --no-cache)
      NO_CACHE="true"
      ;;
    --suffix)
      DOCKER_CACHE_IMAGE="${DOCKER_CACHE_IMAGE}-$2"
      ;;
    --refresh)
      REFRESH="true"
      ;;

  esac
  shift
done

if [[ "$NO_CACHE" == "true" && "$(docker images -q $DOCKER_CACHE_IMAGE 2> /dev/null)" != "" ]]; then
  echo "Removing docker image cache $DOCKER_CACHE_IMAGE"
  docker rmi $DOCKER_CACHE_IMAGE || docker rmi --force $DOCKER_CACHE_IMAGE
fi

if [[ "$(docker images -q $DOCKER_CACHE_IMAGE 2> /dev/null)" == "" ]]; then
  echo "Creating docker cache image"
  docker rm $DOCKER_CACHE_IMAGE 2> /dev/null || true

  docker run --name $DOCKER_CACHE_IMAGE -v "$(realpath "$SOURCE_DIR"):/app" -e ARTIFACTORY_USER=$ARTIFACTORY_USER -e ARTIFACTORY_TOKEN=$ARTIFACTORY_TOKEN $DOCKER_BASE_IMAGE bash -c "
    set -e
    source /app/scripts/rpm-functions.sh
    zypper --non-interactive install gettext gawk
    cleanup-all-repos
    setup-package-repos
    zypper refresh
    # Force a cache update
    zypper --no-refresh info man > /dev/null 2>&1
  "

  echo "Creating cache docker image $DOCKER_CACHE_IMAGE"
  docker commit $DOCKER_CACHE_IMAGE $DOCKER_CACHE_IMAGE
  docker rm $DOCKER_CACHE_IMAGE
fi

if [[ "$REFRESH" == "true" ]]; then
  docker rm $DOCKER_CACHE_IMAGE 2> /dev/null || true
  docker run --name $DOCKER_CACHE_IMAGE -v "$(realpath "$SOURCE_DIR"):/app" --init $DOCKER_CACHE_IMAGE bash -c "
    set -e
    source /app/scripts/rpm-functions.sh
    zypper refresh
    # Force a cache update
    zypper --no-refresh info man > /dev/null 2>&1
  "
  echo "Updating cache docker image $DOCKER_CACHE_IMAGE"
  docker commit $DOCKER_CACHE_IMAGE $DOCKER_CACHE_IMAGE
  docker rm $DOCKER_CACHE_IMAGE

  if [[ -z "$PACKAGES_FILE" ]]; then
    exit 0
  fi
fi

if [[ -z "$PACKAGES_FILE" ]]; then
    echo >&2 "error: missing -p packages-file option"
    usage
    exit 3
fi

echo "Working with packages file $PACKAGES_FILE"

# Only use tty when we'll prompt. This will allow jenkins or other automation to work
if [[ "$VALIDATE" == "true" || "$AUTO_YES" == "true" || OUTPUT_DIFFS_ONLY == "true" ]]; then
  DOCKER_TTY_ARG=""
else
  DOCKER_TTY_ARG="-it"
fi

docker run $DOCKER_TTY_ARG --rm -v "$(realpath "$SOURCE_DIR"):/app" -v "$(realpath "$PACKAGES_FILE"):/packages" --init $DOCKER_CACHE_IMAGE bash -c "
  set -e
  source /app/scripts/rpm-functions.sh
  if [[ \"$VALIDATE\" == \"true\" ]]; then
    validate-package-versions /packages
  else
    cp /packages /tmp/packages
    update-package-versions /tmp/packages ${REPOS_FILTER} ${OUTPUT_DIFFS_ONLY} ${AUTO_YES} ${FILTER}
    cp /tmp/packages /packages
  fi
"
