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

variable "scripts_bucket" {
  type = object({
    id = string
  })
}

variable "vault_kms_key_id" {
  type = string
}

variable "vault_pgp_key" {
  type = string
}
