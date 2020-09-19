#!/bin/bash
set -eu

TEMPLATE_FILE=${TEMPLATE_FILE}
IMAGE_NAME=${IMAGE_NAME}
IMAGE_TAGS_CLI_FLAGS=${IMAGE_TAGS_CLI_FLAGS}
LOG_FILE_DIR=${LOG_FILE_DIR}
ENVS_FROM_LOCAL_EXEC=${ENVS_FROM_LOCAL_EXEC}
PACKER_VARIABLES_JSON=${PACKER_VARIABLES_JSON}


EXISTS_IMAGE="$(aliyun ecs DescribeImages --ImageName=${IMAGE_NAME} ${IMAGE_TAGS_CLI_FLAGS})"
EXISTS_IMAGE_COUNT=$(echo "$EXISTS_IMAGE" | jq .TotalCount)

if [ "$EXISTS_IMAGE_COUNT" -gt 0 ]; then
    echo "$EXISTS_IMAGE" | jq '{image_id: .Images.Image[0].ImageId}'
    exit 0
fi

LOG_DIR="${LOG_FILE_DIR}/alicloud_image"
mkdir -p $LOG_DIR

LOG_FILE="${LOG_DIR}/${IMAGE_NAME}.log"

VAR_FILE="${LOG_DIR}/${IMAGE_NAME}.var.json"
echo "$PACKER_VARIABLES_JSON" > $VAR_FILE

INJECT_SCRIPTS=
eval "${ENVS_FROM_LOCAL_EXEC}"

packer build -machine-readable -timestamp-ui -var "inject_scripts=$INJECT_SCRIPTS" -var-file=$VAR_FILE $TEMPLATE_FILE > $LOG_FILE || {
    cat $LOG_FILE >&2
    exit 1
}

IMAGE_ID=$(fgrep 'artifact,0,id' $LOG_FILE | cut -d : -f2)

echo "{\"image_id\": \"$IMAGE_ID\"}"
