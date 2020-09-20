data "archive_file" "scripts" {
  type        = "zip"
  source_dir  = "${path.module}/scripts"
  output_path = "${path.module}/.tmp/scripts.zip"
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

locals {
  scripts_location = "oss://${var.scripts_bucket.id}/${alicloud_oss_bucket_object.scripts.key}"
}
