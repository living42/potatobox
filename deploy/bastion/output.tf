output "instances" {
  value = [for k, v in alicloud_instance.bastion : v.public_ip]
}
