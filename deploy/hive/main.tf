locals {
  metastore_tags = merge(var.tags, {
    "hive" = "metastore"
  })
}

resource "alicloud_instance" "metastore" {
  for_each = var.metastore_instances

  instance_name        = each.key
  image_id             = var.ecs_image_id
  instance_type        = each.value.instance_type
  system_disk_category = "cloud_efficiency"
  system_disk_size     = 20
  host_name            = each.key
  vswitch_id           = each.value.vswitch_id
  security_groups      = concat(each.value.security_groups, [alicloud_security_group.hive.id])
  key_name             = var.key_name
  role_name            = alicloud_ram_role.hive.id

  spot_strategy    = each.value.spot_strategy
  spot_price_limit = each.value.spot_price_limit

  tags        = local.metastore_tags
  volume_tags = local.metastore_tags

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
    bash $SCRIPTS/setup-alluxio-client.sh
    bash $SCRIPTS/setup-hive.sh ${alicloud_db_instance.hive.id} ${alicloud_db_database.hive.name}
  EOT

  depends_on = [alicloud_db_instance.hive]
}

resource "alicloud_db_instance" "hive" {
  instance_name            = "hive"
  engine                   = "MySQL"
  engine_version           = "8.0"
  instance_type            = var.metastore_db.instance_type
  instance_storage         = var.metastore_db.instance_storage
  db_instance_storage_type = var.metastore_db.instance_storage_type
  zone_id                  = var.metastore_db.zone_id
  vswitch_id               = var.metastore_db.vswitch_ids[0]
  security_group_ids       = [alicloud_security_group.hive.id]
  tags                     = local.metastore_tags
}

resource "alicloud_db_database" "hive" {
  instance_id   = alicloud_db_instance.hive.id
  name          = "hive"
  character_set = "utf8mb4"
}

resource "alicloud_security_group" "hive" {
  name        = "${var.project}-${var.environment}-hive"
  description = "resources in this group will have hive database access"
  tags        = local.metastore_tags
  vpc_id      = var.vpc_id
}

resource "alicloud_ram_role" "hive" {
  name        = "${var.project}-${var.environment}-hive"
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
  description = "role of hive for potatobox"
  force       = true
}

resource "alicloud_ram_policy" "hive" {
  name        = "${var.project}_${var.environment}_hive"
  document    = <<EOF
  {
    "Statement": [
      {
        "Action": [
          "rds:CreateAccount",
          "rds:GrantAccountPrivilege",
          "rds:DescribeDBInstanceNetInfo",
          "rds:ResetAccountPassword"
        ],
        "Effect": "Allow",
        "Resource": [
          "acs:rds:*:*:*/${alicloud_db_instance.hive.id}"
        ]
      }
    ],
    "Version": "1"
  }
  EOF
  description = "hive policy in potatobox"
  force       = true
}

resource "alicloud_ram_role_policy_attachment" "hive" {
  policy_name = alicloud_ram_policy.hive.name
  policy_type = alicloud_ram_policy.hive.type
  role_name   = alicloud_ram_role.hive.name
}

resource "alicloud_ram_role_policy_attachment" "base" {
  for_each = { for i in var.ram_role_policies : i.name => i.type }

  policy_name = each.key
  policy_type = each.value
  role_name   = alicloud_ram_role.hive.name
}
