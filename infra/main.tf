variable "project" {
  type = string
}

variable "environment" {
  type = string
}

locals {
  common_tags = {
    "project"     = var.project
    "environment" = var.environment
    "id"          = "${var.project}-${var.environment}"
  }
}

resource "random_id" "cr_namespace_suffix" {
  byte_length = 4
}

resource "alicloud_cr_namespace" "docker_image_registry" {
  name               = "${var.project}-${var.environment}-${random_id.cr_namespace_suffix.hex}"
  auto_create        = true
  default_visibility = "PRIVATE"
}

output "alicloud_cr_namespace" {
  value = alicloud_cr_namespace.docker_image_registry.id
}

resource "random_id" "scripts_bucket_suffix" {
  byte_length = 4
}

resource "alicloud_oss_bucket" "scripts" {
  bucket        = "${var.project}-${var.environment}-scripts-${random_id.scripts_bucket_suffix.hex}"
  force_destroy = true
  tags          = local.common_tags
}

output "scripts_bucket" {
  value = alicloud_oss_bucket.scripts
}

