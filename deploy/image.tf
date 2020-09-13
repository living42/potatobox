module "basic_image" {
  source = "./modules/alicloud_image"

  src           = "${path.module}/image/basic"
  setup         = "setup.sh"
  image_name    = "basic"
  source_image  = "debian_10_4_x64_20G_alibase_20200717.vhd"
  instance_type = "ecs.n1.tiny"
  tags = {
    "project" = var.project
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
    "project" = var.project
  }

  envs_from_local_exec = {
    "CR_TEMP_USER_PASSWORD" : "aliyun cr GetAuthorizationToken | jq -r .data.authorizationToken"
  }
}


module "hive_image" {
  source = "./modules/alicloud_image"

  src           = "${path.module}/image/hive"
  setup         = "setup.sh"
  image_name    = "hive"
  source_image  = module.alluxio_image.image_id
  instance_type = "ecs.n1.tiny"
  tags = {
    "project" = var.project
  }

  envs_from_local_exec = {
    "CR_TEMP_USER_PASSWORD" : "aliyun cr GetAuthorizationToken | jq -r .data.authorizationToken"
  }
}
