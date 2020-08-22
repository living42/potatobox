#!/bin/sh
set -eu

CONSUL_VERSION=1.8.3

yum install -y yum-utils
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

found_version=$(yum list --showduplicates consul | grep $CONSUL_VERSION | tail -n 1 | awk '{print $2}')
if [ -z "$found_version" ]; then
    echo "consul version $CONSUL_VERSION is not found"
fi

yum install -y consul-$found_version
