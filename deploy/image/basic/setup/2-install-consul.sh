#!/bin/sh
set -eu

CONSUL_VERSION=1.8.3

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -

echo "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list

apt-get update

apt-get install -y consul=$CONSUL_VERSION
