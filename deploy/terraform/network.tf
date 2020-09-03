module "vpc" {
  source = "alibaba/vpc/alicloud"
  region = "cn-shanghai"

  create   = true
  vpc_name = "${var.project}-${var.environment}"
  vpc_cidr = "172.16.0.0/16"

  availability_zones = ["cn-shanghai-e", "cn-shanghai-f", "cn-shanghai-g"]
  vswitch_cidrs      = ["172.16.105.0/24", "172.16.106.0/24", "172.16.107.0/24"]
  vswitch_name       = "${var.project}-${var.environment}-"

  vpc_tags     = local.common_tags
  vswitch_tags = local.common_tags
}

resource "alicloud_security_group" "default" {
  name                = "${var.project}-${var.environment}-default"
  description         = "Default Policy for project ${var.project}"
  tags                = local.common_tags
  vpc_id              = module.vpc.this_vpc_id
  inner_access_policy = "Accept"
}

resource "alicloud_security_group" "jumpserver" {
  name        = "${var.project}-${var.environment}-jumpserver"
  description = "Policy for jumpserver"
  tags        = local.common_tags
  vpc_id      = module.vpc.this_vpc_id
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

resource "alicloud_instance" "jumpserver" {
  instance_name        = "jumpserver"
  image_id             = var.ecs_basic_image_id
  instance_type        = "ecs.s6-c1m1.small"
  system_disk_category = "cloud_efficiency"
  system_disk_size     = 20
  host_name            = "jumpserver"
  vswitch_id           = module.vpc.this_vswitch_ids[0]
  security_groups = [
    alicloud_security_group.default.id,
    alicloud_security_group.jumpserver.id
  ]
  key_name  = alicloud_key_pair.default.key_name
  user_data = <<-EOT
    #!/bin/sh
    set -xe
    SCRIPTS=/root/scripts
    bash $SCRIPTS/setup-consul.sh client '${jsonencode(module.consul.server_addresses)}'
  EOT

  spot_strategy    = "SpotAsPriceGo"
  spot_price_limit = 0.05

  tags        = local.common_tags
  volume_tags = local.common_tags
}
