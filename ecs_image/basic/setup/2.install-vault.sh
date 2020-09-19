#!/bin/sh
set -xeu

VAULT_VERSION=1.5.3

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

# package source is configured in `1-install-consul.sh` already

auto_retry 10 120 apt-get install -y vault=$VAULT_VERSION
