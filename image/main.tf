variable "project" {
  type    = string
  default = "potatobox"
}

module "alluxio" {
  source = "./modules/docker_image"

  context = "${path.module}/alluxio"
  tag     = "${var.project}/alluxio:latest"
}

module "hadoop" {
  source = "./modules/docker_image"

  context = "${path.module}/hadoop"
  tag     = "${var.project}/hadoop:latest"
  build_args = {
    "BASE_IMAGE" = module.alluxio.iid
  }
}

module "hive" {
  source = "./modules/docker_image"

  context = "${path.module}/hive"
  tag     = "${var.project}/hive:latest"
  build_args = {
    "BASE_IMAGE" = module.hadoop.iid
  }
}

module "presto" {
  source = "./modules/docker_image"

  context = "${path.module}/presto"
  tag     = "${var.project}/presto:latest"
  build_args = {
    "ALLUXIO_IMAGE" = module.alluxio.iid
  }
}

module "spark" {
  source = "./modules/docker_image"

  context = "${path.module}/spark"
  tag     = "${var.project}/spark:latest"
  build_args = {
    "BASE_IMAGE"    = module.hive.iid
    "ALLUXIO_IMAGE" = module.alluxio.iid
  }
}
