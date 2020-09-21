resource "alicloud_vpc" "main" {
  name       = "${var.project}-${var.environment}"
  cidr_block = "172.16.0.0/16"
  tags       = local.common_tags
}

resource "alicloud_vswitch" "e" {
  vpc_id            = alicloud_vpc.main.id
  cidr_block        = "172.16.105.0/24"
  availability_zone = "cn-shanghai-e"
  tags              = local.common_tags
}

resource "alicloud_vswitch" "f" {
  vpc_id            = alicloud_vpc.main.id
  cidr_block        = "172.16.106.0/24"
  availability_zone = "cn-shanghai-f"
  tags              = local.common_tags
}

resource "alicloud_vswitch" "g" {
  vpc_id            = alicloud_vpc.main.id
  cidr_block        = "172.16.107.0/24"
  availability_zone = "cn-shanghai-g"
  tags              = local.common_tags
}

resource "alicloud_security_group" "default" {
  name                = "${var.project}-${var.environment}-default"
  description         = "Default Policy for project ${var.project}"
  tags                = local.common_tags
  vpc_id              = alicloud_vpc.main.id
  inner_access_policy = "Accept"
}

resource "alicloud_security_group" "jumpserver" {
  name        = "${var.project}-${var.environment}-jumpserver"
  description = "Policy for jumpserver"
  tags        = local.common_tags
  vpc_id      = alicloud_vpc.main.id
}

resource "alicloud_security_group_rule" "allow_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.jumpserver.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_ping" {
  type              = "ingress"
  ip_protocol       = "icmp"
  nic_type          = "intranet"
  policy            = "accept"
  priority          = 1
  security_group_id = alicloud_security_group.jumpserver.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_eip" "jumpserver_eip" {
  internet_charge_type = "PayByTraffic"
  tags                 = local.common_tags
}

resource "alicloud_eip_association" "jumpserver_eip" {
  allocation_id = alicloud_eip.jumpserver_eip.id
  instance_id   = alicloud_instance.jumpserver.id
}

resource "alicloud_ram_role" "jumpserver" {
  name        = "${var.project}-${var.environment}-jumpserver"
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
  description = "role of jumpserver for potatobox"
  force       = true
}

resource "alicloud_ram_role_policy_attachment" "base" {
  policy_name = module.scripts.ram_policy.name
  policy_type = module.scripts.ram_policy.type
  role_name   = alicloud_ram_role.jumpserver.name
}

resource "alicloud_instance" "jumpserver" {
  instance_name        = "jumpserver"
  image_id             = var.ecs_images.basic
  instance_type        = "ecs.s6-c1m1.small"
  system_disk_category = "cloud_efficiency"
  system_disk_size     = 20
  host_name            = "jumpserver"
  vswitch_id           = alicloud_vswitch.e.id
  security_groups = [
    alicloud_security_group.default.id,
    alicloud_security_group.jumpserver.id
  ]
  key_name  = alicloud_key_pair.default.key_name
  role_name = alicloud_ram_role.jumpserver.id

  user_data = <<-EOT
    #!/bin/sh
    set -xe
    export HOME=/root
    cd $HOME

    setup-aliyun-cli.sh

    aliyun oss cp ${module.scripts.location} scripts.zip
    unzip scripts.zip -d scripts
    SCRIPTS=$PWD/scripts

    bash $SCRIPTS/setup-consul.sh client '${jsonencode(module.consul.server_addresses)}'
  EOT

  spot_strategy    = "SpotAsPriceGo"
  spot_price_limit = 0.05

  tags        = local.common_tags
  volume_tags = local.common_tags
}
