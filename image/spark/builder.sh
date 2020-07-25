#!/usr/bin/env bash

#DEPENDS hive alluxio

set -eu

SPARK2_VERSION=2.4.6
SPARK3_VERSION=3.0.0

BASE_IMAGE=${IMAGE_PREFIX}/hive:${IMAGE_TAG}
IMAGE_NAME=spark

build() {
    docker build -t ${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG} \
        --build-arg BASE_IMAGE=${BASE_IMAGE} \
        --build-arg IMAGE_PREFIX=${IMAGE_PREFIX} \
        --build-arg IMAGE_TAG=${IMAGE_TAG} \
        --build-arg SPARK2_VERSION=${SPARK2_VERSION} \
        --build-arg SPARK3_VERSION=${SPARK3_VERSION} \
        --build-arg APACHE_DIST_MIRROR=${APACHE_DIST_MIRROR} \
        .
}

push() {
    docker push ${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}
}

$1
