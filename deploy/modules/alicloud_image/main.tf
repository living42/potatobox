terraform {
  required_providers {
    shell = {
      source  = "scottwinkler/shell"
      version = "1.7.3"
    }
  }
}

locals {
  src_hash = sha256(join("", [
    for file in fileset(var.src, "**") :
    filesha256("${var.src}/${file}")
  ]))
  tags = merge(var.tags, {
    "name"     = var.image_name
    "src_hash" = local.src_hash
  })
}

locals {
  template = jsonencode({
    "variables" = {
      "build_time"           = "{{env `BUILD_TIME`}}"
      "ENVS_FROM_LOCAL_EXEC" = "{{env `ENVS_FROM_LOCAL_EXEC`}}"
    },
    "builders" = [
      {
        "type"                 = "alicloud-ecs",
        "image_name"           = "${var.image_name}_{{user `build_time`}}",
        "source_image"         = var.source_image,
        "ssh_username"         = "root",
        "instance_type"        = var.instance_type,
        "instance_name"        = "${var.image_name}_{{user `build_time`}}_builder",
        "io_optimized"         = true,
        "internet_charge_type" = "PayByTraffic",
        "system_disk_mapping" = {
          "disk_size"     = 20,
          "disk_category" = "cloud_ssd"
        },
        "tags" = local.tags
      }
    ],
    "provisioners" = [
      {
        "type"         = "shell"
        "pause_before" = "30s"
        "inline"       = "mkdir -p /tmp/build"
      },
      {
        "type"        = "file"
        "source"      = "${abspath(var.src)}/",
        "destination" = "/tmp/build"
      },
      {
        "type" = "shell"
        "inline" = [
          "set -xu",
          "eval \"$${ENVS_FROM_LOCAL_EXEC}\"",
          "cd /tmp/build",
          "chmod +x /tmp/build/${var.setup}",
          "/tmp/build/${var.setup}",
          "rm -rf /tmp/build"
        ]
        "environment_vars" = [
          "ENVS_FROM_LOCAL_EXEC={{user `ENVS_FROM_LOCAL_EXEC`}}"
        ]
      }
    ]
  })

  image_tags_cli_flags = join(" ", concat([
    for i, key in keys(local.tags) :
    "--Tag.${i + 1}.Key=${key}"
    ], [
    for i, val in values(local.tags) :
    "--Tag.${i + 1}.Value=${val}"
  ]))

  cmd = <<-EOF
    set -eu

    EXISTS_IMAGE="$(aliyun ecs DescribeImages ${local.image_tags_cli_flags})"
    EXISTS_IMAGE_COUNT=$(echo "$EXISTS_IMAGE" | jq .TotalCount)

    if [ "$EXISTS_IMAGE_COUNT" -gt 0 ]; then
      echo "$EXISTS_IMAGE" | jq '{image_id: .Images.Image[0].ImageId}'
      exit 0
    fi

    BUILD_TIME="$(date +%Y%m%d%H%M%S)"

    TEMPLATE_FILE=$(mktemp -t ${var.image_name}_$${BUILD_TIME}_template_XXXX.json)
    trap "rm $TEMPLATE_FILE" EXIT
    echo "$TEMPLATE" > $TEMPLATE_FILE


    LOG_FILE=$(mktemp -t ${var.image_name}_$${BUILD_TIME}_build_XXXX.log)
    trap "rm $LOG_FILE" EXIT

    ${templatefile("${path.module}/envs_from_local_exec.tpl", { "items" = var.envs_from_local_exec })}

    export BUILD_TIME

    packer build -machine-readable -timestamp-ui $TEMPLATE_FILE > $LOG_FILE || {
      cat $LOG_FILE >&2
      exit 1
    }

    IMAGE_ID=$(fgrep ',alicloud-ecs,artifact,0,id' $LOG_FILE | cut -d : -f2)

    echo "{\"image_id\": \"$IMAGE_ID\"}"
  EOF
}


resource "shell_script" "image" {
  triggers = {
    cmd      = local.cmd
    template = local.template
  }

  environment = {
    "TEMPLATE" = local.template
  }

  lifecycle_commands {
    create = local.cmd
    delete = "echo"
  }
}
