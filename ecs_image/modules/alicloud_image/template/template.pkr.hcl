variable "envs" {
  type = list(string)
}

variable "inject_scripts" {
  type = string
}

variable "image_name" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "source_dir" {
  type = string
}

variable "setup" {
  type = string
}

variable "source_image" {
  type = string
}

variable "tags" {
  type = map(string)
}

source "alicloud-ecs" "instance" {
  image_name           = var.image_name
  instance_name        = var.instance_name
  instance_type        = var.instance_type
  internet_charge_type = "PayByTraffic"
  io_optimized         = true
  source_image         = var.source_image
  ssh_username         = "root"
  system_disk_mapping {
    disk_category = "cloud_ssd"
    disk_size     = 20
  }
  tags = var.tags
}

build {
  sources = ["source.alicloud-ecs.instance"]

  provisioner "shell" {
    inline = ["mkdir -p /tmp/build"]
  }

  provisioner "file" {
    destination = "/tmp/build"
    source      = "${trimsuffix(abspath(var.source_dir), "/")}/"
  }
  provisioner "shell" {
    inline = [
      "set -xu",
      "cd /tmp/build",
      "chmod +x /tmp/build/${var.setup}",
      "eval \"$INJECT_SCRIPTS\"",
      "/tmp/build/${var.setup}",
      "rm -rf /tmp/build/${var.setup}",
    ]
    environment_vars = concat(var.envs, ["INJECT_SCRIPTS=${var.inject_scripts}"])
  }
}
