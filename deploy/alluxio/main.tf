locals {
  master_tags = merge(var.tags, {
    "alluxio" = "master"
  })
  worker_tags = merge(var.tags, {
    "alluxio" = "worker"
  })
}

resource "alicloud_ram_user" "alluxio" {
  name     = "${var.project}-${var.environment}-alluxio"
  comments = "Represents Alluxio Service behalf in project ${var.project}(${var.environment})"
  force    = true
}

resource "alicloud_ram_policy" "alluxio" {
  name     = "${var.project}-${var.environment}-alluxio"
  document = <<EOF
  {
    "Statement": [
      {
        "Action": [
          "oss:Get*",
          "oss:Put*",
          "oss:List*",
          "oss:Delete*",
          "oss:CopyObject",
          "oss:InitiateMultipartUpload",
          "oss:UploadPart",
          "oss:UploadPartCopy",
          "oss:CompleteMultipartUpload",
          "oss:AbortMultipartUpload",
          "oss:ListParts"
        ],
        "Effect": "Allow",
        "Resource": [
          "acs:oss:*:*:${var.oss_ufs.bucket_name}",
          "acs:oss:*:*:${var.oss_ufs.bucket_name}/*"
        ]
      }
    ],
    "Version": "1"
  }
  EOF
  force    = true
}

resource "alicloud_ram_user_policy_attachment" "alluxio" {
  policy_name = alicloud_ram_policy.alluxio.name
  policy_type = alicloud_ram_policy.alluxio.type
  user_name   = alicloud_ram_user.alluxio.name
}

# create a ram_role and attach to ecs instances, allow instances to create access key by it self

resource "alicloud_ram_role" "alluxio_server" {
  name        = "${var.project}-${var.environment}-alluxio-instance"
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
  description = "role of alluxio servers for potatobox"
  force       = true
}

resource "alicloud_ram_policy" "alluxio_server" {
  name        = "${var.project}_${var.environment}_alluxio_server"
  document    = <<EOF
  {
    "Statement": [
      {
        "Action": [
          "ram:CreateAccessKey"
        ],
        "Effect": "Allow",
        "Resource": [
          "acs:ram:*:*:user/${alicloud_ram_user.alluxio.name}"
        ]
      }
    ],
    "Version": "1"
  }
  EOF
  description = "alluxio servers policy in potatobox"
  force       = true
}

resource "alicloud_ram_role_policy_attachment" "alluxio_server" {
  policy_name = alicloud_ram_policy.alluxio_server.name
  policy_type = alicloud_ram_policy.alluxio_server.type
  role_name   = alicloud_ram_role.alluxio_server.name
}

resource "alicloud_ram_role_policy_attachment" "base" {
  for_each = { for i in var.ram_role_policies : i.name => i.type }

  policy_name = each.key
  policy_type = each.value
  role_name   = alicloud_ram_role.alluxio_server.name
}

# setup masters

resource "alicloud_instance" "masters" {
  for_each = var.master_instances

  instance_name        = each.key
  image_id             = var.ecs_image_id
  instance_type        = each.value.instance_type
  system_disk_category = "cloud_efficiency"
  system_disk_size     = 20
  host_name            = each.key
  vswitch_id           = each.value.vswitch_id
  security_groups      = each.value.security_groups
  key_name             = var.key_name
  role_name            = alicloud_ram_role.alluxio_server.id
  user_data            = <<-EOT
    #!/bin/sh
    set -xe
    export HOME=/root
    cd $HOME

    setup-aliyun-cli.sh

    aliyun oss cp ${var.scripts_location} scripts.zip
    unzip scripts.zip -d scripts
    SCRIPTS=$PWD/scripts

    bash $SCRIPTS/setup-disk.sh /dev/vdb /data
    bash $SCRIPTS/setup-consul.sh client '${jsonencode(var.consul_server_addresses)}'

    ACCESS_KEY="$(bash $SCRIPTS/get-or-create-access-key.sh \
      services/alluxio/alicloud_ram_access_key/${alicloud_ram_user.alluxio.id} \
      ${alicloud_ram_user.alluxio.name})"
    ACCESS_KEY_ID=$(echo "$ACCESS_KEY" | jq .AccessKey.AccessKeyId -r)
    ACCESS_KEY_SECRET=$(echo "$ACCESS_KEY" | jq .AccessKey.AccessKeySecret -r)

    bash $SCRIPTS/setup-alluxio.sh \
      "master job_master" \
      /data/alluxio \
      ${length(var.master_instances)} \
      $ACCESS_KEY_ID \
      $ACCESS_KEY_SECRET \
      ${var.oss_ufs.intranet_endpoint} \
      ${var.oss_ufs.bucket_name}
  EOT

  depends_on = [
    alicloud_ram_policy.alluxio
  ]

  internet_max_bandwidth_out = 10 // trigger to allocate public ip

  spot_strategy    = each.value.spot_strategy
  spot_price_limit = each.value.spot_price_limit

  tags        = local.master_tags
  volume_tags = local.master_tags
}

data "alicloud_vswitches" "masters" {
  ids = [for name, each in var.master_instances : each.vswitch_id]
}

locals {
  vswitch_zone_map_for_masters = { for v in data.alicloud_vswitches.masters.vswitches : v.id => v.zone_id }
}

resource "alicloud_disk" "master_disks" {
  for_each = var.master_instances

  availability_zone = local.vswitch_zone_map_for_masters[each.value.vswitch_id]
  name              = "${each.key}-data-disk"
  category          = each.value.data_disk_category
  size              = each.value.data_disk_size
  tags              = local.master_tags
}

resource "alicloud_disk_attachment" "master_disk_attachment" {
  for_each = alicloud_instance.masters

  disk_id     = alicloud_disk.master_disks[each.key].id
  instance_id = alicloud_instance.masters[each.key].id
}


# setup workers

resource "alicloud_instance" "workers" {
  for_each = var.worker_instances

  depends_on = [alicloud_instance.masters]

  instance_name        = each.key
  image_id             = var.ecs_image_id
  instance_type        = each.value.instance_type
  system_disk_category = "cloud_efficiency"
  system_disk_size     = 20
  host_name            = each.key
  vswitch_id           = each.value.vswitch_id
  security_groups      = each.value.security_groups
  key_name             = var.key_name
  role_name            = alicloud_ram_role.alluxio_server.id
  user_data            = <<-EOT
    #!/bin/sh
    set -xe
    export HOME=/root
    cd $HOME

    setup-aliyun-cli.sh

    aliyun oss cp ${var.scripts_location} scripts.zip
    unzip scripts.zip -d scripts
    SCRIPTS=$PWD/scripts

    bash $SCRIPTS/setup-disk.sh /dev/vdb /data
    bash $SCRIPTS/setup-consul.sh client '${jsonencode(var.consul_server_addresses)}'

    ACCESS_KEY="$(bash $SCRIPTS/get-or-create-access-key.sh \
      services/alluxio/alicloud_ram_access_key/${alicloud_ram_user.alluxio.id} \
      ${alicloud_ram_user.alluxio.name})"
    ACCESS_KEY_ID=$(echo "$ACCESS_KEY" | jq .AccessKey.AccessKeyId -r)
    ACCESS_KEY_SECRET=$(echo "$ACCESS_KEY" | jq .AccessKey.AccessKeySecret -r)

    bash $SCRIPTS/setup-alluxio.sh \
      "worker job_worker" \
      /data/alluxio \
      ${length(var.master_instances)} \
      $ACCESS_KEY_ID \
      $ACCESS_KEY_SECRET \
      ${var.oss_ufs.intranet_endpoint} \
      ${var.oss_ufs.bucket_name}
  EOT

  internet_max_bandwidth_out = 10 // trigger to allocate public ip

  spot_strategy    = each.value.spot_strategy
  spot_price_limit = each.value.spot_price_limit

  tags        = local.worker_tags
  volume_tags = local.worker_tags
}

data "alicloud_vswitches" "workers" {
  ids = [for name, each in var.worker_instances : each.vswitch_id]
}

locals {
  vswitch_zone_map_for_workers = { for v in data.alicloud_vswitches.workers.vswitches : v.id => v.zone_id }
}

resource "alicloud_disk" "worker_disks" {
  for_each = var.worker_instances

  availability_zone = local.vswitch_zone_map_for_workers[each.value.vswitch_id]
  name              = "${each.key}-data-disk"
  category          = each.value.data_disk_category
  size              = each.value.data_disk_size
  tags              = local.worker_tags
}

resource "alicloud_disk_attachment" "worker_disk_attachment" {
  for_each = alicloud_instance.workers

  disk_id     = alicloud_disk.worker_disks[each.key].id
  instance_id = alicloud_instance.workers[each.key].id
}
