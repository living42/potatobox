#!/usr/bin/env bash
set -xeu

# set HOME env to correct config dir location
export HOME=/root

aliyun configure set \
    --profile default \
    --mode EcsRamRole \
    --ram-role-name $(curl -sS 100.100.100.200/2016-01-01/meta-data/ram/security-credentials/) \
    --region $(curl -sS 100.100.100.200/2016-01-01/meta-data/region-id)
aliyun configure list
chmod 700 /root/.aliyun
