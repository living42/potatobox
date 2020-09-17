variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "alicloud_cr_namespace" {
  type = string
}

output "images" {
  value = {
    "alluxio" = module.alluxio.image.vpc
    "hadoop"  = module.hadoop.image.vpc
    "hive"    = module.hive.image.vpc
    "presto"  = module.presto.image.vpc
    "spark"   = module.spark.image.vpc
  }
}

module "alluxio" {
  source = "./modules/docker_image"

  context = "${path.module}/alluxio"
  tag     = "${var.project}/alluxio:latest"

  publish = {
    "namespace" = var.alicloud_cr_namespace
    "repo"      = "alluxio"
    "tag"       = "${var.project}-${var.environment}"
  }
}

module "hadoop" {
  source = "./modules/docker_image"

  context = "${path.module}/hadoop"
  tag     = "${var.project}/hadoop:latest"
  build_args = {
    "BASE_IMAGE" = module.alluxio.iid
  }

  publish = {
    "namespace" = var.alicloud_cr_namespace
    "repo"      = "hadoop"
    "tag"       = "${var.project}-${var.environment}"
  }
}

module "hive" {
  source = "./modules/docker_image"

  context = "${path.module}/hive"
  tag     = "${var.project}/hive:latest"
  build_args = {
    "BASE_IMAGE" = module.hadoop.iid
  }

  publish = {
    "namespace" = var.alicloud_cr_namespace
    "repo"      = "hive"
    "tag"       = "${var.project}-${var.environment}"
  }
}

module "presto" {
  source = "./modules/docker_image"

  context = "${path.module}/presto"
  tag     = "${var.project}/presto:latest"
  build_args = {
    "ALLUXIO_IMAGE" = module.alluxio.iid
  }

  publish = {
    "namespace" = var.alicloud_cr_namespace
    "repo"      = "presto"
    "tag"       = "${var.project}-${var.environment}"
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

  publish = {
    "namespace" = var.alicloud_cr_namespace
    "repo"      = "spark"
    "tag"       = "${var.project}-${var.environment}"
  }
}
