output "instances" {
  value = [
    for name, instance in alicloud_instance.instances : {
      name       = name
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  ]
}

output "recovery_key_url" {
  value = "oss://${alicloud_oss_bucket.vault_init_result.id}/vault-recovery-key"
}

output "initial_root_token_url" {
  value = "oss://${alicloud_oss_bucket.vault_init_result.id}/vault-initial-root-token"
}
