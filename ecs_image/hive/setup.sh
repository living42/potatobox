#!/bin/sh
set -xeu

# Pull container images
echo "${CR_TEMP_USER_PASSWORD}" | docker login \
    --username cr_temp_user \
    --password-stdin \
    ${HIVE_IMAGE}

docker pull -q ${HIVE_IMAGE}
docker tag ${HIVE_IMAGE} hive
docker rmi ${HIVE_IMAGE}
