output "image" {
  value = {
    "public" = "${alicloud_cr_repo.repo.domain_list.public}/${shell_script.publish.output["repo"]}"
    "vpc"    = "${alicloud_cr_repo.repo.domain_list.vpc}/${shell_script.publish.output["repo"]}"
  }
}

output "iid" {
  value = shell_script.image.output["iid"]
}
