provider "alicloud" {
}

resource "alicloud_cr_namespace" "potatobox" {
  name               = "potatobox"
  auto_create        = true
  default_visibility = "PRIVATE"
}
