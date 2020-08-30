provider "alicloud" {
  version = "~> 1.93"
}

module "vpc" {
  source = "alibaba/vpc/alicloud"
  region = "cn-shanghai"

  create   = true
  vpc_name = var.project
  vpc_cidr = "172.16.0.0/16"

  availability_zones = ["cn-shanghai-e", "cn-shanghai-f", "cn-shanghai-g"]
  vswitch_cidrs      = ["172.16.105.0/24", "172.16.106.0/24", "172.16.107.0/24"]
  vswitch_name       = "${var.project}-"

  vpc_tags     = local.common_tags
  vswitch_tags = local.common_tags
}

resource "alicloud_security_group" "default" {
  name                = "${var.project}-default"
  description         = "Default Policy for project ${var.project}"
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
  key_name   = "${var.project}-${var.environment}"
  public_key = file("~/.ssh/aliyun-default.pub")
}

module "consul" {
  source = "./modules/consul"

  project     = var.project
  environment = var.environment

  ecs_image_id = var.ecs_image_id
  key_name     = alicloud_key_pair.default.key_name
  tags         = local.common_tags
  instances = {
    "consul-1" = {
      "instance_type"      = "ecs.ic5.large",
      "vswitch_id"         = module.vpc.this_vswitch_ids[0],
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "consul-2" = {
      "instance_type"      = "ecs.ic5.large",
      "vswitch_id"         = module.vpc.this_vswitch_ids[1],
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "consul-3" = {
      "instance_type"      = "ecs.ic5.large",
      "vswitch_id"         = module.vpc.this_vswitch_ids[2],
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
  }
}

resource "random_id" "alluxio_ufs_oss_bucket_suffix" {
  byte_length = 4
}

resource "alicloud_oss_bucket" "alluxio_ufs" {
  bucket        = "${var.project}-${random_id.alluxio_ufs_oss_bucket_suffix.hex}"
  force_destroy = true
  tags          = local.common_tags
}

module "alluxio" {
  source = "./modules/alluxio"

  project     = var.project
  environment = var.environment

  ecs_image_id = var.ecs_image_id
  key_name     = alicloud_key_pair.default.key_name
  tags         = local.common_tags

  consul_server_addresses = module.consul.server_addresses

  oss_ufs = {
    "bucket_name" = alicloud_oss_bucket.alluxio_ufs.id,
  }

  master_instances = {
    "alluxio-master-1" = {
      "instance_type"      = "ecs.ic5.large",
      "vswitch_id"         = module.vpc.this_vswitch_ids[0],
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "alluxio-master-2" = {
      "instance_type"      = "ecs.ic5.large",
      "vswitch_id"         = module.vpc.this_vswitch_ids[1],
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "alluxio-master-3" = {
      "instance_type"      = "ecs.ic5.large",
      "vswitch_id"         = module.vpc.this_vswitch_ids[2],
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
  }
  worker_instances = {
    "alluxio-worker-1" = {
      "instance_type"      = "ecs.ic5.large",
      "vswitch_id"         = module.vpc.this_vswitch_ids[0],
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
  }
}

locals {
  servers = {
    "consul"  = module.consul.instances,
    "alluxio" = concat(module.alluxio.master_instances, module.alluxio.worker_instances),
  }
}

output "servers" {
  value = local.servers
}

resource "local_file" "ssh_config" {
  content = templatefile("ssh_config.tpl", {
    "ssh_priv_key_file" = "~/.ssh/aliyun-default"
    "servers"           = local.servers
  })
  filename = ".secrets/ssh_config"
}
