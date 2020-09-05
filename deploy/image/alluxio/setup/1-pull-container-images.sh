#!/bin/sh
set -eu

# Pull container images
REGISTRY=${REGISTRY:-registry-vpc.cn-shanghai.aliyuncs.com}
echo "${CR_TEMP_USER_PASSWORD}" | docker login \
    --username cr_temp_user \
    --password-stdin \
    ${REGISTRY}

for i in alluxio; do
    REMOTE_IMAGE=$REGISTRY/potatobox/$i
    docker pull -q $REMOTE_IMAGE
    docker tag $REMOTE_IMAGE $i
    docker rmi $REMOTE_IMAGE
done
