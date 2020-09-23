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

resource "alicloud_kms_key" "vault_kms" {
  description = "Vault KMS For ${var.project}/${var.environment}"

  protection_level = "SOFTWARE"
  key_state        = "Enabled"

  // Duration in days after which the key is deleted after destruction of the resource
  pending_window_in_days = "7"

  automatic_rotation = "Enabled"
  rotation_interval  = "${30 * 24 * 3600}s" // 30 days
}

resource "alicloud_kms_alias" "vault_kms" {
  alias_name = "alias/vault/${var.project}/${var.environment}"
  key_id     = alicloud_kms_key.vault_kms.id
}

output "vault_kms_key_id" {
  value = alicloud_kms_key.vault_kms.id
}
