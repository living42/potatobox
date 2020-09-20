variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "ecs_image_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "consul_server_addresses" {
  type = list(string)
}

variable "oss_ufs" {
  type = object({
    bucket_name       = string
    intranet_endpoint = string
  })
}

variable "master_instances" {
  type = map(object({
    instance_type      = string
    vswitch_id         = string
    security_groups    = list(string)
    data_disk_category = string
    data_disk_size     = number
    spot_strategy      = string
    spot_price_limit   = number
  }))
}

variable "worker_instances" {
  type = map(object({
    instance_type      = string
    vswitch_id         = string
    security_groups    = list(string)
    data_disk_category = string
    data_disk_size     = number
    spot_strategy      = string
    spot_price_limit   = number
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "scripts_location" {
  type = string
}

variable "ram_role_policies" {
  type = list(object({ name = string, type = string }))
}
