#!/usr/bin/env bash

#DEPENDS hadoop

set -eu

HIVE_VERSION=3.1.2

BASE_IMAGE=${IMAGE_PREFIX}/hadoop:${IMAGE_TAG}
IMAGE_NAME=hive

build() {
    docker build -t ${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG} \
        --build-arg BASE_IMAGE=${BASE_IMAGE} \
        --build-arg HIVE_VERSION=${HIVE_VERSION} \
        --build-arg APACHE_DIST_MIRROR=${APACHE_DIST_MIRROR} \
        .
}

push() {
    docker push ${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}
}

$1
