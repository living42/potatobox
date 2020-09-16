variable "project" {
  type    = string
  default = "potatobox"
}

variable "environment" {
  type    = string
  default = "develop"
}


module "infra" {
  source = "./infra"

  project     = var.project
  environment = var.environment
}

module "image" {
  source = "./image"

  project               = var.project
  environment           = var.environment
  alicloud_cr_namespace = module.infra.alicloud_cr_namespace
}

module "deploy" {
  source = "./deploy"

  project     = var.project
  environment = var.environment

  alluxio_docker_image = module.image.alluxio_image
  hive_docker_image    = module.image.hive_image
  presto_docker_image  = module.image.presto_image
}
