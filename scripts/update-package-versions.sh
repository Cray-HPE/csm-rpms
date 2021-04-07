#!/usr/bin/env bash

function usage(){
    cat <<EOF
Usage:
    update-package-versions.sh PACKAGES_FILE

    Will check latest package versions and prompt to update that version the csm-rpms
    packages file

EOF
}

SOURCE_DIR="$(dirname $0)/.."
SOURCE_DIR="$(pushd "$SOURCE_DIR" > /dev/null && pwd && popd > /dev/null)"

OUTPUT_DIFFS_ONLY="false"

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
    -o|--output-diffs-only)
      OUTPUT_DIFFS_ONLY="true"
      ;;
    -n|--no-cache)
      NO_CACHE="true"
      ;;
    -r|--refresh)
      REFRESH="true"
      ;;

  esac
  shift
done


if [[ -z "$PACKAGES_FILE" ]]; then
    echo >&2 "error: missing -p packaages-file option"
    exit 3
fi

echo "Updating packages file $PACKAGES_FILE"

DOCKER_CACHE_IMAGE="csm-rpms-cache"
DOCKER_BASE_IMAGE="opensuse/leap:15.2"

if [[ "$NO_CACHE" == "true" && "$(docker images -q $DOCKER_CACHE_IMAGE 2> /dev/null)" != "" ]]; then
  echo "Removing docker image cache $DOCKER_CACHE_IMAGE"
  docker rmi --force $DOCKER_CACHE_IMAGE
fi

if [[ "$(docker images -q $DOCKER_CACHE_IMAGE 2> /dev/null)" == "" ]]; then
  echo "Creating docker cache image"
  docker rm $DOCKER_CACHE_IMAGE 2> /dev/null || true

  docker run -it --name $DOCKER_CACHE_IMAGE -v $SOURCE_DIR:/csm-rpms $DOCKER_BASE_IMAGE bash -c "
    source /csm-rpms/scripts/rpm-functions.sh
    setup-package-repos
    zypper refresh
    # Force a cache update
    zypper --no-refresh info man
  "

  echo "Creating cache docker image $DOCKER_CACHE_IMAGE"
  docker commit $DOCKER_CACHE_IMAGE $DOCKER_CACHE_IMAGE
  docker rm $DOCKER_CACHE_IMAGE
fi

docker run -it --rm -v $SOURCE_DIR:/csm-rpms --init $DOCKER_CACHE_IMAGE bash -c "
  source /csm-rpms/scripts/rpm-functions.sh
  if [[ \"$REFRESH\" == \"true\" ]]; then
    zypper refresh
    # Force a cache update
    zypper --no-refresh info man
  fi

  update-package-versions /csm-rpms/${PACKAGES_FILE} ${OUTPUT_DIFFS_ONLY} ${FILTER}
"
