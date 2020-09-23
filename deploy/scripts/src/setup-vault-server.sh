#!/bin/sh
set -xeu

KMS_KEY_ID=$1

INSTANCE_IP=$(curl 100.100.100.200/2016-01-01/meta-data/private-ipv4)
REGION=$(curl 100.100.100.200/2016-01-01/meta-data/region-id)

cat <<EOF > /etc/vault.d/vault.hcl
ui = true

storage "consul" {
  address = "consul.service.consul:8500"
  path    = "vault/"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://${INSTANCE_IP}:8200"

seal "alicloudkms" {
  region = "${REGION}"
  kms_key_id = "${KMS_KEY_ID}"
}
EOF

systemctl enable vault
systemctl start vault
