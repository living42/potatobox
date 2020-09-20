variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "ecs_image_id" {
  type = string
}

variable "consul_server_addresses" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "vpc_id" {
  type = string
}

variable "metastore_db" {
  type = object({
    instance_type         = string,
    instance_storage      = number,
    instance_storage_type = string,
    vswitch_ids           = list(string),
    zone_id               = string
  })
}

variable "metastore_instances" {
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

variable "scripts_location" {
  type = string
}

variable "ram_role_policies" {
  type = list(object({ name = string, type = string }))
}
