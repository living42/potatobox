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

module "docker_image" {
  source = "./docker_image"

  project     = var.project
  environment = var.environment

  alicloud_cr_namespace = module.infra.alicloud_cr_namespace
}

module "ecs_image" {
  source = "./ecs_image"

  project     = var.project
  environment = var.environment

  docker_images = module.docker_image.images
}

module "deploy" {
  source = "./deploy"

  project     = var.project
  environment = var.environment

  ecs_images = module.ecs_image.images
}
