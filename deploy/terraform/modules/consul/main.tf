locals {
  consul_server_tags = merge(var.tags, {
    "consul" = "server"
  })
  consul_server_node_tags_cli_flags = join(" ", concat([
    for i, key in keys(local.consul_server_tags) :
    "--Tag.${i + 1}.Key=${key}"
    ], [
    for i, val in values(local.consul_server_tags) :
    "--Tag.${i + 1}.Value=${val}"
  ]))
}

resource "alicloud_instance" "consul_servers" {
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
  role_name            = alicloud_ram_role.consul_server.id
  user_data            = <<-EOT
    #!/bin/sh
    set -xe
    SCRIPTS=/usr/local/share/potatobox/scripts
    bash $SCRIPTS/setup-disk.sh /dev/vdb /data
    bash $SCRIPTS/setup-aliyun-cli.sh
    bash $SCRIPTS/setup-consul.sh server /data/consul "${local.consul_server_node_tags_cli_flags}"
  EOT

  internet_max_bandwidth_out = 10 // trigger to allocate public ip

  spot_strategy    = each.value.spot_strategy
  spot_price_limit = each.value.spot_price_limit

  tags        = local.consul_server_tags
  volume_tags = local.consul_server_tags
}

data "alicloud_vswitches" "vswitches" {
  ids = [for k, v in var.instances : v.vswitch_id]
}

locals {
  vswitch_zone_map = { for v in data.alicloud_vswitches.vswitches.vswitches : v.id => v.zone_id }
}

resource "alicloud_disk" "consul_server_disks" {
  for_each = var.instances

  availability_zone = local.vswitch_zone_map[each.value.vswitch_id]
  name              = "${each.key}-data-disk"
  category          = each.value.data_disk_category
  size              = each.value.data_disk_size
  tags              = local.consul_server_tags
}

resource "alicloud_disk_attachment" "consul_server_disk_attachment" {
  for_each = alicloud_instance.consul_servers

  disk_id     = alicloud_disk.consul_server_disks[each.key].id
  instance_id = alicloud_instance.consul_servers[each.key].id
}

resource "alicloud_ram_role" "consul_server" {
  name        = "${var.project}-${var.environment}-consul-server"
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
  description = "role of consul servers for potatobox"
  force       = true
}

resource "alicloud_ram_policy" "consul_server" {
  name = "${var.project}_${var.environment}_consul_server"
  // ecs:DescribeInstances are required for consul to bootstrap
  document    = <<EOF
  {
    "Statement": [
      {
        "Action": [
          "ecs:DescribeInstances"
        ],
        "Effect": "Allow",
        "Resource": [
          "*"
        ]
      }
    ],
    "Version": "1"
  }
  EOF
  description = "consul servers policy in potatobox"
  force       = true
}

resource "alicloud_ram_role_policy_attachment" "consul_server" {
  policy_name = alicloud_ram_policy.consul_server.name
  policy_type = alicloud_ram_policy.consul_server.type
  role_name   = alicloud_ram_role.consul_server.name
}
