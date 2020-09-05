provider "alicloud" {
  version = "~> 1.95.0"
}

locals {
  common_tags = {
    "project"     = var.project
    "environment" = var.environment
    "id"          = "${var.project}-${var.environment}"
  }
}

module "basic_image" {
  source = "./modules/alicloud_image"

  src           = "${path.module}/image/basic"
  setup         = "setup.sh"
  image_name    = "basic"
  source_image  = "debian_10_4_x64_20G_alibase_20200717.vhd"
  instance_type = "ecs.n1.tiny"
  tags = {
    "project" = "potatobox"
  }
}

module "alluxio_image" {
  source = "./modules/alicloud_image"

  src           = "${path.module}/image/alluxio"
  setup         = "setup.sh"
  image_name    = "alluxio"
  source_image  = module.basic_image.image_id
  instance_type = "ecs.n1.tiny"
  tags = {
    "project" = "potatobox"
  }

  envs_from_local_exec = {
    "CR_TEMP_USER_PASSWORD" : "aliyun cr GetAuthorizationToken | jq -r .data.authorizationToken"
  }
}

resource "alicloud_key_pair" "default" {
  key_name   = "${var.project}-${var.environment}"
  public_key = file(".secrets/ssh_key.pub")
}

module "consul" {
  source = "./modules/consul"

  project     = var.project
  environment = var.environment

  ecs_image_id = module.basic_image.image_id
  key_name     = alicloud_key_pair.default.key_name
  tags         = local.common_tags
  instances = {
    "consul-1" = {
      "instance_type"      = "ecs.s6-c1m1.small",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "consul-2" = {
      "instance_type"      = "ecs.xn4.small",
      "vswitch_id"         = alicloud_vswitch.f.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "consul-3" = {
      "instance_type"      = "ecs.s6-c1m1.small",
      "vswitch_id"         = alicloud_vswitch.g.id,
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

  ecs_image_id = module.alluxio_image.image_id
  key_name     = alicloud_key_pair.default.key_name
  tags         = local.common_tags

  consul_server_addresses = module.consul.server_addresses

  oss_ufs = {
    "bucket_name" = alicloud_oss_bucket.alluxio_ufs.id,
  }

  master_instances = {
    "alluxio-master-1" = {
      "instance_type"      = "ecs.t5-lc1m2.small",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "alluxio-master-2" = {
      "instance_type"      = "ecs.t5-lc1m2.small",
      "vswitch_id"         = alicloud_vswitch.f.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "alluxio-master-3" = {
      "instance_type"      = "ecs.t5-lc1m2.small",
      "vswitch_id"         = alicloud_vswitch.g.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
  }
  worker_instances = {
    "alluxio-worker-1" = {
      "instance_type"      = "ecs.t5-lc1m2.small",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
  }
}

resource "local_file" "ssh_config" {
  content = templatefile("helpers/ssh_config.tpl", {
    "ssh_priv_key_file" = ".secrets/ssh_key"
    "jumpserver" = {
      "ip" = alicloud_eip.jumpserver_eip.ip_address
    },
    "internal_instances" = concat(
      module.consul.instances,
      module.alluxio.master_instances,
      module.alluxio.worker_instances
    )
  })
  filename = ".secrets/ssh_config"
}
