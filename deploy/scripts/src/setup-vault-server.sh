#!/bin/sh
set -xeu

KMS_KEY_ID=$1
PGP_KEY=$2
CREDENTIAL_BUCKET=$3

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

sleep 15

cat <<EOF | consul lock -shell -pass-stdin -child-exit-code lock/vault-init bash -s
set -xeu
export VAULT_ADDR=http://127.0.0.1:8200

if [ "false" = "\$(vault status -format json | jq .initialized)" ]; then
  vault operator init \
    -recovery-shares=1 -recovery-threshold=1 -recovery-pgp-keys=$PGP_KEY \
    -root-token-pgp-key=$PGP_KEY \
    | tee /tmp/vault-init-result.txt

  aliyun oss cp /tmp/vault-init-result.txt oss://$CREDENTIAL_BUCKET/vault-init-result

  cat /tmp/vault-init-result.txt \
    | sed -n -E 's/Recovery Key .+: (.+)/\1/p' | base64 -d > /tmp/vault-recovery-key
  aliyun oss cp /tmp/vault-recovery-key oss://$CREDENTIAL_BUCKET/vault-recovery-key
  rm /tmp/vault-recovery-key

  cat /tmp/vault-init-result.txt \
    | sed -n -E 's/Initial Root Token: (.+)/\1/p' | base64 -d > /tmp/vault-initial-root-token
  aliyun oss cp /tmp/vault-initial-root-token oss://$CREDENTIAL_BUCKET/vault-initial-root-token
  rm /tmp/vault-initial-root-token

  rm /tmp/vault-init-result.txt
fi
EOF
