terraform {
  required_providers {
    shell = {
      source  = "scottwinkler/shell"
      version = "1.7.3"
    }
  }
}

locals {
  hashes = concat(
    [for file in sort(fileset(var.src, "**")) : filesha256("${var.src}/${file}")],
    [for kv in sort([for k, v in var.envs : "${k}=${v}"]) : sha256(kv)],
    [for kv in sort([for k, v in var.envs_from_local_exec : "${k}=${v}"]) : sha256(kv)]
  )

  hash = sha256(join("", local.hashes))
  tags = merge(var.tags, {
    "name" = var.image_name
  })
  // alicloud limits image_name to 128 characters
  image_name = substr("${var.image_name}_${local.hash}", 0, 128)
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
        "image_name"           = local.image_name,
        "source_image"         = var.source_image,
        "ssh_username"         = "root",
        "instance_type"        = var.instance_type,
        "instance_name"        = substr("${local.image_name}_builder", 0, 128),
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
        "environment_vars" = concat([
          "ENVS_FROM_LOCAL_EXEC={{user `ENVS_FROM_LOCAL_EXEC`}}"
        ], [for k, v in var.envs : "${k}=${v}"])
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

    EXISTS_IMAGE="$(aliyun ecs DescribeImages --ImageName=${local.image_name} ${local.image_tags_cli_flags})"
    EXISTS_IMAGE_COUNT=$(echo "$EXISTS_IMAGE" | jq .TotalCount)

    if [ "$EXISTS_IMAGE_COUNT" -gt 0 ]; then
      echo "$EXISTS_IMAGE" | jq '{image_id: .Images.Image[0].ImageId}'
      exit 0
    fi

    BUILD_TIME="$(date +%Y%m%d%H%M%S)"

    CLEANUP=true
    trap 'eval "$CLEANUP"' EXIT

    TEMPLATE_FILE=$(mktemp -t ${var.image_name}_$${BUILD_TIME}_template_XXXX.json)
    CLEANUP="$CLEANUP; rm $TEMPLATE_FILE"
    echo "$TEMPLATE" > $TEMPLATE_FILE


    LOG_FILE=$(mktemp -t ${var.image_name}_$${BUILD_TIME}_build_XXXX.log)
    CLEANUP="$CLEANUP; rm $LOG_FILE"

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
