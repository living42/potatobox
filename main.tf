terraform {
  required_version = "0.13.3"
  required_providers {
    alicloud = "~> 1.95.0"
    local    = "~> 1.4.0"
    random   = "~> 2.3.0"
    archive  = "~> 1.3.0"
  }

  backend "oss" {
    bucket  = "living42"
    prefix  = "potatobox/state"
    key     = "terraform.tfstate"
    region  = "cn-hangzhou"
    encrypt = true
  }
}

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

  vault_kms_key_id = module.infra.vault_kms_key_id
}

output "bastion_ips" {
  value = module.deploy.bastion_ips
}
