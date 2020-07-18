#!/usr/bin/env bash

#DEPENDS alluxio

set -eu

HADOOP_VERSION=3.2.1

BASE_IMAGE=${IMAGE_PREFIX}/alluxio:${IMAGE_TAG}
IMAGE_NAME=hadoop

docker build -t ${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG} \
    --build-arg BASE_IMAGE=${BASE_IMAGE} \
    --build-arg HADOOP_VERSION=${HADOOP_VERSION} \
    --build-arg APACHE_DIST_MIRROR=${APACHE_DIST_MIRROR} \
    .
