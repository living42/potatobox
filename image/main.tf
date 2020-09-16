variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "alicloud_cr_namespace" {
  type = string
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

output "alluxio_image" {
  value = module.alluxio.image
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

output "hadoop_image" {
  value = module.hadoop.image
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

output "hive_image" {
  value = module.hive.image
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

output "presto_image" {
  value = module.presto.image
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

output "spark_image" {
  value = module.spark.image
}
