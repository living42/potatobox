output "location" {
  value = "oss://${alicloud_oss_bucket.scripts.id}/${alicloud_oss_bucket_object.scripts.key}"
}

output "ram_policy" {
  value = alicloud_ram_policy.scripts
}
