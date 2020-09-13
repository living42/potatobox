output "metastore_instances" {
  value = [
    for name, instance in alicloud_instance.metastore : {
      name       = name
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  ]
}
