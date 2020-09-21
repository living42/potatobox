locals {
  tags = merge(var.tags, {
    "vault" = "vault"
  })
}

resource "alicloud_instance" "instances" {
  for_each = var.instances

  instance_name        = each.key
  image_id             = var.ecs_image_id
  instance_type        = each.value.instance_type
  system_disk_category = "cloud_efficiency"
  system_disk_size     = 20
  host_name            = each.key
  vswitch_id           = each.value.vswitch_id
  security_groups      = each.value.security_groups
  key_name             = var.key_name
  role_name            = alicloud_ram_role.vault.id

  spot_strategy    = each.value.spot_strategy
  spot_price_limit = each.value.spot_price_limit

  tags        = local.tags
  volume_tags = local.tags

  internet_max_bandwidth_out = 10 // trigger to allocate public ip

  user_data = <<-EOT
    #!/bin/sh
    set -xe
    export HOME=/root
    cd $HOME

    setup-aliyun-cli.sh

    aliyun oss cp ${var.scripts_location} scripts.zip
    unzip scripts.zip -d scripts
    SCRIPTS=$PWD/scripts

    bash $SCRIPTS/setup-consul.sh client '${jsonencode(var.consul_server_addresses)}'
    bash $SCRIPTS/setup-vault-server.sh \
      ${var.kms_key_id} ${var.pgp_key} ${alicloud_oss_bucket.vault_init_result.id}
  EOT

  depends_on = [alicloud_ram_role_policy_attachment.vault]
}

resource "random_id" "vault_init_result_bucket_suffix" {
  byte_length = 4
}

// bucket to store encrypted unseal key and root token
resource "alicloud_oss_bucket" "vault_init_result" {
  bucket        = "${var.project}-${var.environment}-vault-${random_id.vault_init_result_bucket_suffix.hex}"
  force_destroy = true
  tags          = local.tags
}

resource "alicloud_ram_role" "vault" {
  name        = "${var.project}-${var.environment}-vault"
  document    = <<EOF
  {
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": [
            "ecs.aliyuncs.com"
          ]
        }
      }
    ],
    "Version": "1"
  }
  EOF
  description = "role of Vault for ${var.project}/${var.environment}"
  force       = true
}


resource "alicloud_ram_policy" "vault" {
  name        = "${var.project}_${var.environment}_vault"
  document    = <<EOF
  {
    "Statement": [
      {
        "Action": [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*"
        ],
        "Effect": "Allow",
        "Resource": [
          "acs:kms:*:*:key/${var.kms_key_id}"
        ]
      },
      {
        "Action": [
          "oss:PutObject"
        ],
        "Effect": "Allow",
        "Resource": [
          "acs:oss:*:*:${alicloud_oss_bucket.vault_init_result.id}/*"
        ]
      }
    ],
    "Version": "1"
  }
  EOF
  description = "vault policy in ${var.project}/${var.environment}"
  force       = true
}

resource "alicloud_ram_role_policy_attachment" "vault" {
  policy_name = alicloud_ram_policy.vault.name
  policy_type = alicloud_ram_policy.vault.type
  role_name   = alicloud_ram_role.vault.name
}

resource "alicloud_ram_role_policy_attachment" "base" {
  for_each = { for i in var.ram_role_policies : i.name => i.type }

  policy_name = each.key
  policy_type = each.value
  role_name   = alicloud_ram_role.vault.name
}
