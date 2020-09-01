#!/usr/bin/env bash
set -xeu

device=$1
mount_point=$2

blkid $device || {
    if [ $? = 2 ]; then
        # got a blank block
        mkfs.ext4 $device
    else
        exit $?
    fi
}

UUID=$(blkid -o value $device | head -n 1)
echo "UUID=$UUID $mount_point ext4 defaults 0 2" >> /etc/fstab

mkdir $mount_point
mount $mount_point
