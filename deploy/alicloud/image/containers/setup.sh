#!/bin/sh
set -eu

# Pull container images
REGISTRY=${REGISTRY:-registry-vpc.cn-shanghai.aliyuncs.com}
echo "${CR_TEMP_USER_PASSWORD}" | docker login \
    --username cr_temp_user \
    --password-stdin \
    ${REGISTRY}
for i in alluxio hadoop hive presto spark; do
    docker pull -q "$REGISTRY/potatobox/$i"
done
