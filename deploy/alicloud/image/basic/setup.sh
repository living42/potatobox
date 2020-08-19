#!/bin/sh
set -eu

# Install Docker
DOCKER_VERSION=${DOCKER_VERSION:-19.03.10}
curl -fsSL https://get.docker.com -o get-docker.sh
env VERSION=$DOCKER_VERSION sh get-docker.sh --mirror Aliyun
rm get-docker.sh

systemctl enable docker
systemctl start docker
sleep 5

# Install Docker Compose
# todo copy from container image docker/compose:$VERSION
DOCKER_COMPOSE_VERSION=${DOCKER_COMPOSE_VERSION:-1.26.2}
wget -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)"
chmod +x /usr/local/bin/docker-compose
