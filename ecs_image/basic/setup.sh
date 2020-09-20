#!/bin/sh
set -xeu

chmod -R a+x scripts
cp -r scripts/* /usr/local/sbin/

cd setup

for script in $(ls); do
    echo start execute $script
    chmod +x $script
    ./$script
    echo end execute $script
done
