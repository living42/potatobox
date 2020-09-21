output "location" {
  value = "oss://${var.scripts_bucket.id}/${alicloud_oss_bucket_object.scripts.key}"
}

output "ram_policy" {
  value = alicloud_ram_policy.scripts
}
