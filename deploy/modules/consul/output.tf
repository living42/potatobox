output "instances" {
  value = [
    for name, instance in alicloud_instance.consul_servers : {
      name       = name
      private_ip = instance.private_ip
    }
  ]
}

output "server_addresses" {
  value = [for name, instance in alicloud_instance.consul_servers : instance.private_ip]
}
