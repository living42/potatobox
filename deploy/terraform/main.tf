provider "alicloud" {
  version = "~> 1.93"
}

variable "project_name" {
  type    = string
  default = "potatobox"
}

variable "environment" {
  type    = string
  default = "testing"
}

variable "ecs_image_id" {
  type = string
}

locals {
  common_tags = {
    "project"     = var.project_name
    "environment" = var.environment
    "id"          = "${var.project_name}-${var.environment}"
  }
}

module "vpc" {
  source = "alibaba/vpc/alicloud"
  region = "cn-shanghai"

  create   = true
  vpc_name = var.project_name
  vpc_cidr = "172.16.0.0/16"

  availability_zones = ["cn-shanghai-e", "cn-shanghai-f", "cn-shanghai-g"]
  vswitch_cidrs      = ["172.16.105.0/24", "172.16.106.0/24", "172.16.107.0/24"]
  vswitch_name       = "${var.project_name}-"

  vpc_tags     = local.common_tags
  vswitch_tags = local.common_tags
}

resource "alicloud_security_group" "default" {
  name                = "${var.project_name}-default"
  description         = "Default Policy for project ${var.project_name}"
  tags                = local.common_tags
  vpc_id              = module.vpc.this_vpc_id
  inner_access_policy = "Accept"
}

resource "alicloud_security_group_rule" "allow_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_ping" {
  type              = "ingress"
  ip_protocol       = "icmp"
  nic_type          = "intranet"
  policy            = "accept"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_key_pair" "default" {
  key_name   = "${var.project_name}-${var.environment}"
  public_key = file("~/.ssh/aliyun-default.pub")
}

## Core Node

variable "core_node_data_disk_type" {
  type    = string
  default = "cloud_efficiency"
}

variable "core_node_data_disk_size" {
  type    = number
  default = 20
}

locals {
  core_nodes = {
    "core-1" = {
      "availability_zone" = "cn-shanghai-e",
      "instance_type"     = "ecs.ic5.large",
      "spot_strategy"     = "SpotAsPriceGo",
      "spot_price_limit"  = 0.12
    },
    "core-2" = {
      "availability_zone" = "cn-shanghai-f",
      "instance_type"     = "ecs.ic5.large",
      "spot_strategy"     = "SpotAsPriceGo",
      "spot_price_limit"  = 0.12
    },
    "core-3" = {
      "availability_zone" = "cn-shanghai-g",
      "instance_type"     = "ecs.ic5.large",
      "spot_strategy"     = "SpotAsPriceGo",
      "spot_price_limit"  = 0.12
    }
  }
}

locals {
  core_node_tags_cli_flags = join(" ", concat([
    for i, key in keys(local.core_node_tags) :
    "--Tag.${i + 1}.Key=${key}"
    ], [
    for i, val in values(local.core_node_tags) :
    "--Tag.${i + 1}.Value=${val}"
  ]))

  alluxio_access_key = jsondecode(file(".keys/alluxio-access-key.txt"))
}

resource "alicloud_instance" "core_nodes" {
  for_each = local.core_nodes

  instance_name              = "${var.project_name}_${replace(each.key, "-", "_")}"
  image_id                   = var.ecs_image_id
  instance_type              = each.value.instance_type
  system_disk_category       = "cloud_efficiency"
  system_disk_size           = 20
  internet_max_bandwidth_out = 10 // allocate public ip
  host_name                  = each.key
  vswitch_id                 = module.vpc.this_vswitch_ids[index(module.vpc.this_availability_zones, each.value.availability_zone)]
  security_groups            = [alicloud_security_group.default.id]
  key_name                   = alicloud_key_pair.default.key_name
  role_name                  = alicloud_ram_role.core_node.name
  # TODO passing local.core_node_tags to setup-consul.sh instead of hard code
  user_data = <<-EOT
    #!/bin/sh
    set -xe
    SCRIPTS=/usr/local/share/potatobox/scripts
    bash $SCRIPTS/setup-disk.sh /dev/vdb /data
    bash $SCRIPTS/setup-aliyun-cli.sh
    bash $SCRIPTS/setup-consul.sh server /data/consul "${local.core_node_tags_cli_flags}"
    bash $SCRIPTS/setup-alluxio.sh \
      "master job_master worker job_worker" \
      /data/alluxio \
      ${length(local.core_nodes)} \
      ${local.alluxio_access_key.AccessKeyId} \
      ${local.alluxio_access_key.AccessKeySecret} \
      ${alicloud_oss_bucket.alluxio_underfs.intranet_endpoint} \
      ${alicloud_oss_bucket.alluxio_underfs.id} \
  EOT

  spot_strategy    = each.value.spot_strategy
  spot_price_limit = each.value.spot_price_limit

  tags        = local.core_node_tags
  volume_tags = local.core_node_tags
}

resource "alicloud_disk" "core_node_disks" {
  for_each          = local.core_nodes
  availability_zone = each.value.availability_zone
  name              = "${each.key}-data-disk"
  category          = var.core_node_data_disk_type
  size              = var.core_node_data_disk_size
  tags              = local.core_node_tags
}

resource "alicloud_disk_attachment" "core_node_disk_attachment" {
  for_each    = local.core_nodes
  disk_id     = alicloud_disk.core_node_disks[each.key].id
  instance_id = alicloud_instance.core_nodes[each.key].id
}

locals {
  core_node_tags = merge(local.common_tags, {
    "consul" = "consul"
  })
}

resource "alicloud_ram_role" "core_node" {
  name        = "${var.project_name}-core-node"
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
  description = "role of core node for potatobox"
  force       = true
}

resource "alicloud_ram_policy" "core_node" {
  name = "${var.project_name}_core_node"
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
  description = "core node policy for potatobox"
  force       = true
}

resource "alicloud_ram_role_policy_attachment" "core_node" {
  policy_name = alicloud_ram_policy.core_node.name
  policy_type = alicloud_ram_policy.core_node.type
  role_name   = alicloud_ram_role.core_node.name
}

output "core_nodes" {
  value = {
    for k, v in alicloud_instance.core_nodes : k => v.public_ip
  }
}

resource "null_resource" "ssh_config" {
  triggers = {
    template_hash   = filesha1("ssh_config.tpl")
    core_nodes_hash = sha1(jsonencode(alicloud_instance.core_nodes))
  }
  provisioner "local-exec" {
    command = "echo \"$SSH_CONFIG\" > .keys/ssh_config"
    environment = {
      SSH_CONFIG = templatefile("ssh_config.tpl", {
        ssh_priv_key_file = "~/.ssh/aliyun-default"
        core_nodes        = alicloud_instance.core_nodes
      })
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "rm .keys/ssh_config"
  }
}

# Alluxio
resource "random_id" "alluxio_oss_bucket_suffix" {
  byte_length = 4
}

resource "alicloud_oss_bucket" "alluxio_underfs" {
  bucket        = "${var.project_name}-${random_id.alluxio_oss_bucket_suffix.hex}"
  force_destroy = true
  tags          = local.common_tags
}

resource "alicloud_ram_user" "alluxio" {
  name     = "${var.project_name}_alluxio"
  comments = "Represents Alluxio Service behalf in project ${var.project_name}"
}

resource "alicloud_ram_access_key" "alluxio" {
  user_name   = alicloud_ram_user.alluxio.name
  secret_file = ".keys/alluxio-access-key.txt"
}

resource "alicloud_ram_policy" "alluxio" {
  name     = "${var.project_name}_alluxio"
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
          "acs:oss:*:*:${alicloud_oss_bucket.alluxio_underfs.id}",
          "acs:oss:*:*:${alicloud_oss_bucket.alluxio_underfs.id}/*"
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
