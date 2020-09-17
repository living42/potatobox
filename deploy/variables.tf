variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "ecs_images" {
  type = object({
    basic   = string
    alluxio = string
    hive    = string
    presto  = string
  })
}
