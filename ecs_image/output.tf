output "images" {
  value = {
    "basic"   = module.basic.image_id
    "alluxio" = module.alluxio.image_id
    "hive"    = module.hive.image_id
    "presto"  = module.presto.image_id
  }
}
