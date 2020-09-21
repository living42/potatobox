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
