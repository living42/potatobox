#!/usr/bin/env bash

#DEPENDS alluxio

set -eu

PRESTO_VERSION=339

BASE_IMAGE=openjdk:11
IMAGE_NAME=presto

build() {
    [ "${PULL_BASE_IMAGE}" = yes ] && docker pull ${BASE_IMAGE}

    docker build -t ${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG} \
        --build-arg BASE_IMAGE=${BASE_IMAGE} \
        --build-arg PRESTO_VERSION=${PRESTO_VERSION} \
        --build-arg IMAGE_PREFIX=${IMAGE_PREFIX} \
        --build-arg IMAGE_TAG=${IMAGE_TAG} \
        .
}

push() {
    docker push ${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}
}

$1
