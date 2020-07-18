#!/usr/bin/env bash
set -eu

export IMAGE_PREFIX=${IMAGE_PREFIX:-potatobox}
export IMAGE_TAG=${IMAGE_TAG:-latest}
export APACHE_DIST_MIRROR=${APACHE_DIST_MIRROR:-"https://mirrors.aliyun.com/apache"}
export PULL_BASE_IMAGE=${PULL_BASE_IMAGE:-yes}


if [ -n "${1:-}" ]; then
    scripts=$1/build.sh
    [ -f "$scripts" ] || {
        echo target $1 is not exists
        exit 1
    }
else
    scripts=$(ls */build.sh)
fi

# TODO implements #DEPENDS tag semantic

for script in $scripts; do
    pushd $(dirname $script)
    echo run $script
    bash $(basename $script)
    popd
done
