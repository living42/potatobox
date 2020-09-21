locals {
  // alicloud_oss_bucket_object could not check file changes, use this technique to trigger re-upload
  // the downside is we are left many old file in ${path.module}/.tmp, is could not clean automatically
  hash = sha256(join("", [
    for i in fileset("${path.module}/src", "**") :
    "${i}:${filesha256("${path.module}/src/${i}")}"
  ]))
}

data "archive_file" "scripts" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/.tmp/scripts_${local.hash}.zip"
}

resource "alicloud_oss_bucket_object" "scripts" {
  bucket = var.scripts_bucket.id
  key    = "scripts.zip"
  source = data.archive_file.scripts.output_path
}

resource "alicloud_ram_policy" "scripts" {
  name     = "${var.project}-${var.environment}-scripts"
  document = <<EOF
  {
    "Statement": [
      {
        "Action": [
          "oss:Get*"
        ],
        "Effect": "Allow",
        "Resource": [
          "acs:oss:*:*:${var.scripts_bucket.id}/*"
        ]
      }
    ],
    "Version": "1"
  }
  EOF
  force    = true
}
