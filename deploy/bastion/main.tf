
resource "alicloud_security_group" "bastion" {
  name        = "${var.project}-${var.environment}-bastion"
  description = "Policy for bastion"
  tags        = var.tags
  vpc_id      = var.vpc_id
}

resource "alicloud_security_group_rule" "allow_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.bastion.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_ping" {
  type              = "ingress"
  ip_protocol       = "icmp"
  nic_type          = "intranet"
  policy            = "accept"
  priority          = 1
  security_group_id = alicloud_security_group.bastion.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_ram_role" "bastion" {
  name        = "${var.project}-${var.environment}-bastion"
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
  description = "role of bastion for potatobox"
  force       = true
}

resource "alicloud_ram_role_policy_attachment" "base" {
  for_each = { for i in var.ram_role_policies : i.name => i.type }

  policy_name = each.key
  policy_type = each.value
  role_name   = alicloud_ram_role.bastion.name
}

resource "alicloud_instance" "bastion" {
  for_each = var.instances

  instance_name        = each.key
  image_id             = var.ecs_image_id
  instance_type        = each.value.instance_type
  system_disk_category = "cloud_efficiency"
  system_disk_size     = 20
  vswitch_id           = each.value.vswitch_id
  security_groups      = concat(each.value.security_groups, [alicloud_security_group.bastion.id])
  key_name             = var.key_name
  host_name            = each.key
  role_name            = alicloud_ram_role.bastion.id

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
  EOT

  spot_strategy    = each.value.spot_strategy
  spot_price_limit = each.value.spot_price_limit

  tags        = var.tags
  volume_tags = var.tags

  internet_max_bandwidth_out = 10 // trigger to allocate public ip
}
