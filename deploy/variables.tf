variable "project" {
  type = string
}

variable "environment" {
  type = string
}


variable "alluxio_docker_image" {
  type = object({
    public = string
    vpc    = string
  })
}

variable "hive_docker_image" {
  type = object({
    public = string
    vpc    = string
  })
}

variable "presto_docker_image" {
  type = object({
    public = string
    vpc    = string
  })
}
