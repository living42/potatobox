variable "project" {
  type    = string
  default = "potatobox"
}

variable "environment" {
  type    = string
  default = "develop"
}

variable "docker_images" {
  type = object({
    alluxio = string
    hadoop  = string
    hive    = string
    presto  = string
    spark   = string
  })
}
