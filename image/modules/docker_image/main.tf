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
    for file in sort(fileset(var.context, "**")) :
    filesha256("${var.context}/${file}")
  ]))
  slug           = replace(var.tag, "/[^a-zA-Z0-9]/", "_")
  build_args_cli = join(" ", [for key, val in var.build_args : "--build-arg ${key}=${val}"])
  cmd            = <<-EOF
    set -eu
    cd ${var.context}

    BUILD_TIME="$(date +%Y%m%d%H%M%S)"

    CLEANUP=true
    trap 'eval "$CLEANUP"' EXIT

    LOG_FILE=$(mktemp -t ${local.slug}_$${BUILD_TIME}_build_XXXX.log)
    CLEANUP="$CLEANUP; rm $LOG_FILE"
    IID_FILE=$(mktemp -t ${local.slug}_$${BUILD_TIME}_iid_XXXX.txt)
    CLEANUP="$CLEANUP; rm $IID_FILE"

    docker build --iidfile $IID_FILE -t ${local.slug} ${local.build_args_cli} . > $LOG_FILE || {
      cat $LOG_FILE >&2
      exit 1
    }

    IID=$(cat $IID_FILE)
    echo "{\"iid\": \"$IID\"}"
  EOF
}

resource "shell_script" "image" {
  triggers = {
    cmd      = local.cmd
    src_hash = local.src_hash
  }

  lifecycle_commands {
    create = local.cmd
    delete = "echo"
  }
}
