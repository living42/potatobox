#!/bin/sh
set -xeu

# Pull container images
echo "${CR_TEMP_USER_PASSWORD}" | docker login \
    --username cr_temp_user \
    --password-stdin \
    ${PRESTO_IMAGE}

docker pull -q ${PRESTO_IMAGE}
docker tag ${PRESTO_IMAGE} presto
docker rmi ${PRESTO_IMAGE}
