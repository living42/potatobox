#!/bin/sh
set -eu

CONSUL_VERSION=1.8.3

auto_retry() {
    max_attempts=$1
    shift
    retry_wait=$1
    shift
    cmd=$@

    attempt=0
    while true; do
        attempt=$(($attempt+1))
        ($cmd)
        rc=$?
        if [ $rc -eq 0 ]; then
            break
        fi

        if [ $attempt -le $max_attempts ]; then
            echo "retry later (attempt: $attempt)"
            sleep $retry_wait
        else
            echo "too many retry (attempt: $attempt)"
            return $rc
        fi
    done
}

auto_retry 10 120 curl -fsSL -o key https://apt.releases.hashicorp.com/gpg
apt-key add key
rm key

echo "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list

auto_retry 10 120 apt-get update

auto_retry 10 120 apt-get install -y consul=$CONSUL_VERSION
