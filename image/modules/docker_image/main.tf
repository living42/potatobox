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
  create         = <<-EOF
    set -eu
    cd ${var.context}

    BUILD_TIME="$(date +%Y%m%d%H%M%S)"

    CLEANUP=true
    trap 'eval "$CLEANUP"' EXIT

    LOG_FILE=$(mktemp -t ${local.slug}_$${BUILD_TIME}_build_XXXX.log)
    CLEANUP="$CLEANUP; rm $LOG_FILE"

    docker build -t ${local.slug} ${local.build_args_cli} . > $LOG_FILE || {
      cat $LOG_FILE >&2
      exit 1
    }

    iid=$(docker image inspect ${local.slug} --format '{{.Id}}')
    echo "{\"iid\": \"$iid\"}"
  EOF
}

resource "shell_script" "image" {
  triggers = {
    src_hash = local.src_hash
  }

  lifecycle_commands {
    create = local.create
    delete = "docker rmi ${local.slug}"
  }
}

resource "alicloud_cr_repo" "repo" {
  namespace = var.publish.namespace
  name      = var.publish.repo
  summary   = var.publish.repo
  repo_type = "PRIVATE"
}

resource "shell_script" "publish" {
  triggers = {
    iid      = shell_script.image.output["iid"]
    registry = alicloud_cr_repo.repo.domain_list.public
  }

  lifecycle_commands {
    create = <<EOF
      set -eu
      TIME="$(date +%Y%m%d%H%M%S)"
      REGISTRY="${alicloud_cr_repo.repo.domain_list.public}"
      IID="${shell_script.image.output["iid"]}"

      CLEANUP=true
      trap 'eval "$CLEANUP"' EXIT

      LOG_FILE=$(mktemp -t ${local.slug}_$${TIME}_push_XXXX.log)
      CLEANUP="$CLEANUP; rm $LOG_FILE"

      aliyun cr GetAuthorizationToken \
        | jq -r .data.authorizationToken \
        | docker login -u cr_temp_user $REGISTRY --password-stdin > /dev/null
      CLEANUP="$CLEANUP; docker logout $REGISTRY > /dev/null || true"

      URI="$REGISTRY/${alicloud_cr_repo.repo.id}"

      docker tag $IID $URI >> $LOG_FILE || {
        cat $LOG_FILE >&2
        exit 1
      }
      CLEANUP="$CLEANUP; docker rmi $URI > /dev/null"

      docker push $URI >> $LOG_FILE || {
        cat $LOG_FILE >&2
        exit 1
      }

      DIGEST="$(cat $LOG_FILE | grep 'digest: sha256' | awk '{print $3}')"
      echo "{\"digest\":\"$DIGEST\"}"
    EOF
    delete = "true"
  }
}
