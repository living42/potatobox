output "ips" {
  value = { for k, v in alicloud_instance.bastion : k => v.public_ip }
}
