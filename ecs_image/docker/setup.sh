#!/bin/sh
set -xeu

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

auto_retry() {
    max_attempts=$1
    shift
    retry_wait=$1
    shift
    cmd=$@

    attempt=0
    while true; do
        attempt=$(($attempt+1))
        ($cmd) && break || {
            rc=$?
            if [ $attempt -le $max_attempts ]; then
                echo "retry later (attempt: $attempt, rc: $rc)"
                sleep $retry_wait
                continue
            else
                echo "too many retry (attempt: $attempt)"
                return $rc
            fi
        }
    done
}

auto_retry 10 120 \
    wget -O /usr/local/bin/docker-compose \
        "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)"

chmod +x /usr/local/bin/docker-compose
