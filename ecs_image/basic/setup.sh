#!/bin/sh
set -xeu

mkdir -p /root/scripts

cp -r scripts/* /root/scripts/

cd setup

for script in $(ls); do 
    echo start execute $script
    chmod +x $script
    ./$script
    echo end execute $script
done
