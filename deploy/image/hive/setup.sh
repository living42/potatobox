#!/bin/sh
set -xeu

cp -r scripts/* /root/scripts/


# Pull container images
REGISTRY=${REGISTRY:-registry-vpc.cn-shanghai.aliyuncs.com}
echo "${CR_TEMP_USER_PASSWORD}" | docker login \
    --username cr_temp_user \
    --password-stdin \
    ${REGISTRY}

REMOTE_IMAGE=$REGISTRY/potatobox/hive
docker pull -q $REMOTE_IMAGE
docker tag $REMOTE_IMAGE hive
docker rmi $REMOTE_IMAGE
