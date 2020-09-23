provider "alicloud" {
  region = "cn-shanghai"
}

locals {
  common_tags = {
    "project"     = var.project
    "environment" = var.environment
    "id"          = "${var.project}-${var.environment}"
  }
}

resource "alicloud_key_pair" "default" {
  key_name   = "${var.project}-${var.environment}"
  public_key = file("${path.module}/.secrets/ssh_key.pub")
}

module "scripts" {
  source = "./scripts"

  project     = var.project
  environment = var.environment
  tags        = local.common_tags
}

module "consul" {
  source = "./consul"

  depends_on = [module.scripts]

  project     = var.project
  environment = var.environment

  ecs_image_id = var.ecs_images.basic
  key_name     = alicloud_key_pair.default.key_name
  tags         = local.common_tags

  scripts_location  = module.scripts.location
  ram_role_policies = [module.scripts.ram_policy]

  instances = {
    "consul-1" = {
      "instance_type"               = "ecs.t5-lc2m1.nano",
      "vswitch_id"                  = alicloud_vswitch.e.id,
      "security_groups"             = [alicloud_security_group.default.id],
      "data_disk_category"          = "cloud_efficiency",
      "data_disk_size"              = 20,
      "data_disk_availability_zone" = alicloud_vswitch.e.availability_zone,
      "spot_strategy"               = "SpotAsPriceGo",
      "spot_price_limit"            = 0.12,
    },
    "consul-2" = {
      "instance_type"               = "ecs.t5-lc2m1.nano",
      "vswitch_id"                  = alicloud_vswitch.f.id,
      "security_groups"             = [alicloud_security_group.default.id],
      "data_disk_category"          = "cloud_efficiency",
      "data_disk_size"              = 20,
      "data_disk_availability_zone" = alicloud_vswitch.f.availability_zone,
      "spot_strategy"               = "SpotAsPriceGo",
      "spot_price_limit"            = 0.12,
    },
    "consul-3" = {
      "instance_type"               = "ecs.t5-lc2m1.nano",
      "vswitch_id"                  = alicloud_vswitch.g.id,
      "security_groups"             = [alicloud_security_group.default.id],
      "data_disk_category"          = "cloud_efficiency",
      "data_disk_size"              = 20,
      "data_disk_availability_zone" = alicloud_vswitch.g.availability_zone,
      "spot_strategy"               = "SpotAsPriceGo",
      "spot_price_limit"            = 0.12,
    }
  }
}

module "bastion" {
  source = "./bastion"

  depends_on = [module.scripts, module.consul]

  project      = var.project
  environment  = var.environment
  ecs_image_id = var.ecs_images.basic
  key_name     = alicloud_key_pair.default.key_name
  tags         = local.common_tags

  vpc_id = alicloud_vpc.main.id

  instances = {
    "bustion-1" = {
      "instance_type"      = "ecs.t5-lc2m1.nano",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
  }

  scripts_location  = module.scripts.location
  ram_role_policies = [module.scripts.ram_policy]

  consul_server_addresses = module.consul.server_addresses
}

module "vault" {
  source = "./vault"

  depends_on = [module.scripts, module.consul]

  project      = var.project
  environment  = var.environment
  ecs_image_id = var.ecs_images.basic
  key_name     = alicloud_key_pair.default.key_name
  tags         = local.common_tags

  kms_key_id = var.vault_kms_key_id

  scripts_location  = module.scripts.location
  ram_role_policies = [module.scripts.ram_policy]

  consul_server_addresses = module.consul.server_addresses

  instances = {
    "vault-1" = {
      "instance_type"      = "ecs.t5-lc2m1.nano",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
    "vault-2" = {
      "instance_type"      = "ecs.t5-lc2m1.nano",
      "vswitch_id"         = alicloud_vswitch.f.id,
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
  bucket        = "${var.project}-${var.environment}-${random_id.alluxio_ufs_oss_bucket_suffix.hex}"
  force_destroy = true
  tags          = local.common_tags
}

module "alluxio" {
  source = "./alluxio"

  depends_on = [module.scripts, module.consul]

  project     = var.project
  environment = var.environment

  ecs_image_id = var.ecs_images.alluxio
  key_name     = alicloud_key_pair.default.key_name
  tags         = local.common_tags

  consul_server_addresses = module.consul.server_addresses

  oss_ufs = {
    "bucket_name"       = alicloud_oss_bucket.alluxio_ufs.id
    "intranet_endpoint" = alicloud_oss_bucket.alluxio_ufs.intranet_endpoint
  }

  scripts_location  = module.scripts.location
  ram_role_policies = [module.scripts.ram_policy]

  master_instances = {
    "alluxio-1" = {
      "instance_type"      = "ecs.c5.large",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "alluxio-2" = {
      "instance_type"      = "ecs.c5.large",
      "vswitch_id"         = alicloud_vswitch.f.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "alluxio-3" = {
      "instance_type"      = "ecs.c5.large",
      "vswitch_id"         = alicloud_vswitch.g.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
  }
  worker_instances = {
    "alluxio-4" = {
      "instance_type"      = "ecs.c5.large",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
  }
}

module "hive" {
  source = "./hive"

  depends_on = [module.scripts, module.consul, module.alluxio]

  project     = var.project
  environment = var.environment

  ecs_image_id            = var.ecs_images.hive
  consul_server_addresses = module.consul.server_addresses
  key_name                = alicloud_key_pair.default.key_name

  scripts_location  = module.scripts.location
  ram_role_policies = [module.scripts.ram_policy]

  vpc_id = alicloud_vpc.main.id

  tags = local.common_tags

  metastore_db = {
    instance_type         = "rds.mysql.t1.small"
    instance_storage      = 10
    instance_storage_type = "local_ssd"
    vswitch_ids           = [alicloud_vswitch.e.id, alicloud_vswitch.f.id]
    zone_id               = "cn-shanghai-MAZ4(e,f)"
  }

  metastore_instances = {
    "hive-1" = {
      "instance_type"      = "ecs.t5-lc1m1.small",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "hive-2" = {
      "instance_type"      = "ecs.t5-lc1m1.small",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
  }
}

module "presto" {
  source = "./presto"

  depends_on = [module.scripts, module.consul, module.hive]

  project     = var.project
  environment = var.environment

  ecs_image_id            = var.ecs_images.presto
  consul_server_addresses = module.consul.server_addresses
  key_name                = alicloud_key_pair.default.key_name

  scripts_location  = module.scripts.location
  ram_role_policies = [module.scripts.ram_policy]

  tags = local.common_tags

  oss_ufs = {
    "bucket_name"       = alicloud_oss_bucket.alluxio_ufs.id
    "intranet_endpoint" = alicloud_oss_bucket.alluxio_ufs.intranet_endpoint
  }

  coordinator = "presto-1"

  instances = {
    "presto-1" = {
      "instance_type"      = "ecs.c5.large",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "presto-2" = {
      "instance_type"      = "ecs.c5.large",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "presto-3" = {
      "instance_type"      = "ecs.c5.large",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    },
    "presto-4" = {
      "instance_type"      = "ecs.c5.large",
      "vswitch_id"         = alicloud_vswitch.e.id,
      "security_groups"    = [alicloud_security_group.default.id],
      "data_disk_category" = "cloud_efficiency",
      "data_disk_size"     = 20,
      "spot_strategy"      = "SpotAsPriceGo",
      "spot_price_limit"   = 0.12,
    }
  }
}
