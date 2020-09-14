variable "context" {
  type = string
}

variable "tag" {
  type = string
}

variable "build_args" {
  type    = map(string)
  default = {}
}
