#!/usr/bin/env bash
set -xeu

device=$1
mount_point=$2

# setup data disk (only if device is a empty block)
mount | grep $device -q || {
    mkfs.ext4 $device
    echo "$device $mount_point ext4 defaults 0 2" >> /etc/fstab
    mkdir $mount_point
    mount $mount_point
}
