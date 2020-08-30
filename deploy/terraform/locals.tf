locals {
  common_tags = {
    "project"     = var.project
    "environment" = var.environment
    "id"          = "${var.project}-${var.environment}"
  }
}
