output "master_instances" {
  value = [
    for name, instance in alicloud_instance.masters : {
      name       = name
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  ]
}

output "worker_instances" {
  value = [
    for name, instance in alicloud_instance.workers : {
      name       = name
      private_ip = instance.private_ip
    }
  ]
}
