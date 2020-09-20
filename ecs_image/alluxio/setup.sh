#!/bin/sh
set -xeu

# Pull container images
echo "${CR_TEMP_USER_PASSWORD}" | docker login \
    --username cr_temp_user \
    --password-stdin \
    ${ALLUXIO_IMAGE}

docker pull -q ${ALLUXIO_IMAGE}
docker tag ${ALLUXIO_IMAGE} alluxio
docker rmi ${ALLUXIO_IMAGE}
