variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "scripts_bucket" {
  type = object({
    id = string
  })
}
