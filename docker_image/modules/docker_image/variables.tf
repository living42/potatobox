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

variable "publish" {
  type = object({
    namespace = string
    repo      = string
    tag       = string
  })
}
