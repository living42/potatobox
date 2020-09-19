module "basic" {
  source = "./modules/alicloud_image"

  src           = "${path.module}/basic"
  setup         = "setup.sh"
  image_name    = "basic"
  source_image  = "debian_10_4_x64_20G_alibase_20200717.vhd"
  instance_type = "ecs.n1.tiny"
  tags = {
    "project" = var.project
  }
}

module "docker" {
  source = "./modules/alicloud_image"

  src           = "${path.module}/docker"
  setup         = "setup.sh"
  image_name    = "docker"
  source_image  = module.basic.image_id
  instance_type = "ecs.n1.tiny"
  tags = {
    "project" = var.project
  }
}

module "alluxio" {
  source = "./modules/alicloud_image"

  src           = "${path.module}/alluxio"
  setup         = "setup.sh"
  image_name    = "alluxio"
  source_image  = module.docker.image_id
  instance_type = "ecs.n1.tiny"
  tags = {
    "project" = var.project
  }

  envs = {
    "ALLUXIO_IMAGE" = var.docker_images.alluxio
  }
  envs_from_local_exec = {
    "CR_TEMP_USER_PASSWORD" : "aliyun cr GetAuthorizationToken | jq -r .data.authorizationToken"
  }
}


module "hive" {
  source = "./modules/alicloud_image"

  src           = "${path.module}/hive"
  setup         = "setup.sh"
  image_name    = "hive"
  source_image  = module.alluxio.image_id
  instance_type = "ecs.n1.tiny"
  tags = {
    "project" = var.project
  }

  envs = {
    "HIVE_IMAGE" = var.docker_images.hive
  }
  envs_from_local_exec = {
    "CR_TEMP_USER_PASSWORD" : "aliyun cr GetAuthorizationToken | jq -r .data.authorizationToken"
  }
}


module "presto" {
  source = "./modules/alicloud_image"

  src           = "${path.module}/presto"
  setup         = "setup.sh"
  image_name    = "presto"
  source_image  = module.alluxio.image_id
  instance_type = "ecs.n1.tiny"
  tags = {
    "project" = var.project
  }

  envs = {
    "PRESTO_IMAGE" = var.docker_images.presto
  }
  envs_from_local_exec = {
    "CR_TEMP_USER_PASSWORD" : "aliyun cr GetAuthorizationToken | jq -r .data.authorizationToken"
  }
}
