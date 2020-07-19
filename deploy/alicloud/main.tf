provider "alicloud" {
}

resource "random_id" "oss_bucket_suffix" {
  byte_length = 4
}

resource "alicloud_oss_bucket" "potatobox" {
  bucket        = "potatobox-${random_id.oss_bucket_suffix.hex}"
  force_destroy = true
}

resource "alicloud_ram_user" "alluxio_cluster" {
  name = "alluxio_cluster"
}

resource "alicloud_ram_access_key" "alluxio_cluster_ak" {
  user_name   = alicloud_ram_user.alluxio_cluster.name
  secret_file = "secrets/ak-alluxio-cluster.txt"
}

resource "alicloud_ram_policy" "alluxio_cluster_oss_policy" {
  name     = "alluxio_cluster_oss_policy"
  document = <<EOF
  {
    "Statement": [
      {
        "Action": [
          "oss:Get*",
          "oss:Put*",
          "oss:List*",
          "oss:Delete*",
          "oss:CopyObject",
          "oss:InitiateMultipartUpload",
          "oss:UploadPart",
          "oss:UploadPartCopy",
          "oss:CompleteMultipartUpload",
          "oss:AbortMultipartUpload",
          "oss:ListParts"
        ],
        "Effect": "Allow",
        "Resource": [
          "acs:oss:*:*:${alicloud_oss_bucket.potatobox.id}"
        ]
      }
    ],
    "Version": "1"
  }
  EOF
  force    = true
}

resource "alicloud_ram_user_policy_attachment" "alluxio_cluster_oss_policy_attach" {
  policy_name = alicloud_ram_policy.alluxio_cluster_oss_policy.name
  policy_type = alicloud_ram_policy.alluxio_cluster_oss_policy.type
  user_name   = alicloud_ram_user.alluxio_cluster.name
}
