#!/usr/bin/env bash
set -eu

ALLUXIO_VERSION=2.3.0

BASE_IMAGE=openjdk:8
IMAGE_NAME=alluxio

[ "${PULL_BASE_IMAGE}" = yes ] && docker pull ${BASE_IMAGE}

docker build -t ${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG} \
    --build-arg BASE_IMAGE=${BASE_IMAGE} \
    --build-arg ALLUXIO_VERSION=${ALLUXIO_VERSION} \
    .
