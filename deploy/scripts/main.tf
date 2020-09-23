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


resource "random_id" "scripts_bucket_suffix" {
  byte_length = 4
}

resource "alicloud_oss_bucket" "scripts" {
  bucket        = "${var.project}-${var.environment}-scripts-${random_id.scripts_bucket_suffix.hex}"
  force_destroy = true
  tags          = var.tags
}


resource "alicloud_oss_bucket_object" "scripts" {
  bucket = alicloud_oss_bucket.scripts.id
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
          "acs:oss:*:*:${alicloud_oss_bucket.scripts.id}/*"
        ]
      }
    ],
    "Version": "1"
  }
  EOF
  force    = true
}
