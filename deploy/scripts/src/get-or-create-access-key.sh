#!/usr/bin/env bash

set -eu

PREFIX=$1
RAM_USER=$2

GET_OR_CREATE=$(cat <<EOF
set -e
ACCESS_KEY_BASE64=\$(consul kv get $PREFIX || true)
if [ -z "\$ACCESS_KEY_BASE64" ]; then
    ACCESS_KEY=\$(env HOME=/root aliyun ram CreateAccessKey --UserName $RAM_USER)
    ACCESS_KEY_BASE64=\$(echo "\$ACCESS_KEY" | base64 -w 0)
    consul kv put $PREFIX "\$ACCESS_KEY_BASE64" 1>&2
else
    ACCESS_KEY=\$(echo "\$ACCESS_KEY_BASE64" | base64 -d)
fi

echo "\$ACCESS_KEY"
EOF
)

consul lock -shell $PREFIX "$GET_OR_CREATE"
