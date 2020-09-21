output "vault_recovery_key_url" {
  value = module.vault.recovery_key_url
}

output "vault_initial_root_token_url" {
  value = module.vault.initial_root_token_url
}

output "bastion_ips" {
  value = module.bastion.ips
}
