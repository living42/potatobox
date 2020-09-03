variable "project" {
  type    = string
  default = "potatobox"
}

variable "environment" {
  type    = string
  default = "testing"
}

variable "ecs_basic_image_id" {
  type = string
}

variable "ecs_image_id" {
  type = string
}
