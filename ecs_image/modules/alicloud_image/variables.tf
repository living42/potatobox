
variable "tags" {
  type = map(string)

}

variable "src" {
  type = string
}

variable "setup" {
  type    = string
  default = "setup.sh"
}

variable "image_name" {
  type = string
}

variable "source_image" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "envs_from_local_exec" {
  type    = map(string)
  default = {}
}

variable "envs" {
  type    = map(string)
  default = {}
}
