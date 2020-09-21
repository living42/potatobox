#!/usr/bin/env bash
set -xeu

device=$1
mount_point=$2

# this might happend, while machine is up and running, but the disk have not attached yet
deadline=$(($(date +%s)+600))
while [ ! -b $device -a ! $(date +%s) -ge "$deadline" ]; do
    echo "waiting device $device attach"
    sleep 5
done

if [ ! -b $device ]; then
    echo "no such device"
    exit 1
fi

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
