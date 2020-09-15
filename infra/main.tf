variable "project" {
  type = string
}

variable "environment" {
  type = string
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
