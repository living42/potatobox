output "instances" {
  value = [
    for name, instance in alicloud_instance.instances : {
      name       = name
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  ]
}
