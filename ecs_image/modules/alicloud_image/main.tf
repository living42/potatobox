terraform {
  required_providers {
    shell = {
      source  = "scottwinkler/shell"
      version = "1.7.3"
    }
  }
}

locals {
  log_dir = "${abspath(path.root)}/.logs"
}

locals {
  hashes = concat(
    [for file in sort(fileset(path.module, "**")) : filesha256("${path.module}/${file}")],
    [for file in sort(fileset(var.src, "**")) : filesha256("${var.src}/${file}")],
    [var.setup, var.image_name, var.source_image, var.instance_type],
    sort([for k, v in var.tags : "${k}=${v}"]),
    sort([for k, v in var.envs : "${k}=${v}"]),
    sort([for k, v in var.envs_from_local_exec : "${k}=${v}"]),
  )
  hash = sha256(join("", local.hashes))

  tags = merge(var.tags, {
    "name" = var.image_name
  })

  image_tags_cli_flags = join(" ", concat([
    for i, key in keys(local.tags) :
    "--Tag.${i + 1}.Key=${key}"
    ], [
    for i, val in values(local.tags) :
    "--Tag.${i + 1}.Value=${val}"
  ]))

  packer_variables = {
    "envs" = [for k, v in var.envs : "${k}=${v}"]
    // alicloud limits image_name to 128 characters
    "image_name"    = substr("${var.image_name}_${local.hash}", 0, 128)
    "instance_name" = substr("packer_${var.image_name}_${local.hash}", 0, 128)
    "instance_type" = var.instance_type
    "source_dir"    = var.src
    "setup"         = var.setup
    "source_image"  = var.source_image
    "tags"          = local.tags
  }
}

resource "shell_script" "image" {
  triggers = {
    hash = local.hash
  }

  environment = {
    "TEMPLATE_FILE"         = "${path.module}/template/template.pkr.hcl"
    "IMAGE_NAME"            = var.image_name
    "IMAGE_TAGS_CLI_FLAGS"  = local.image_tags_cli_flags
    "LOG_FILE_DIR"          = local.log_dir
    "ENVS_FROM_LOCAL_EXEC"  = templatefile("${path.module}/envs_from_local_exec.tpl", { "items" = var.envs_from_local_exec })
    "PACKER_VARIABLES_JSON" = jsonencode(local.packer_variables)
  }

  lifecycle_commands {
    create = "bash ${path.module}/build.sh"
    delete = "true"
  }
}
