output "instances" {
  value = [
    for name, instance in merge(alicloud_instance.coordinator, alicloud_instance.worker) : {
      name       = name
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  ]
}
