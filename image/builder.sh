#!/usr/bin/env bash
set -eu

export IMAGE_PREFIX=${IMAGE_PREFIX:-potatobox}
export IMAGE_TAG=${IMAGE_TAG:-latest}
export APACHE_DIST_MIRROR=${APACHE_DIST_MIRROR:-"https://mirrors.aliyun.com/apache"}
export PULL_BASE_IMAGE=${PULL_BASE_IMAGE:-yes}


do_action() {
    action=$1
    shift
    targets=$@

    if [ -n "$targets" ]; then
        scripts=""
        for target in $targets; do
            script=$target/builder.sh
            [ -f "$script" ] || {
                echo target $1 is not exists
                exit 1
            }
            scripts="$scripts $script"
        done
    else
        scripts=$(ls */builder.sh)
    fi

    # TODO implements #DEPENDS tag semantic

    for script in $scripts; do
        pushd $(dirname $script)
        echo run $script $action
        bash $(basename $script) $action
        popd
    done
}

help() {
    echo 'usage ./build.sh (action) [target]'
    echo '  actions'
    echo '    build: build images'
    echo '    push: push images to registry'
    echo ''
    echo '  target'
    echo '    target: select which image should build, omit means run action on all targets'
}


case ${1:-help} in
    help)
        help
        ;;
    build|push)
        do_action $@
        ;;
    *)
        echo unknown action $1
        echo ''
        help
        exit 1
        ;;
esac
