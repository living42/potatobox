#!/bin/sh
set -xeu

/bin/bash -c "$(curl -sL https://git.io/vokNn)"

apt-fast install -y axel
