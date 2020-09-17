#!/bin/sh
set -xeu

wget https://aliyuncli.alicdn.com/aliyun-cli-linux-3.0.16-amd64.tgz -O aliyun-cli.tgz
tar xaf aliyun-cli.tgz -C /usr/local/bin
rm -f aliyun-cli.tgz
