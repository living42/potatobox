#!/bin/sh
set -xeu

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

auto_retry 10 120 curl -fsSL -o key https://apt.releases.hashicorp.com/gpg
apt-key add key
rm key

echo "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list

auto_retry 10 120 apt-get update

auto_retry 10 120 apt-get install -y consul=$CONSUL_VERSION

# Install Consul Template

CONSUL_TEMPLATE_VERSION=0.25.1

auto_retry 10 120 \
    wget -O consul-template.tgz \
        https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.tgz

tar xf consul-template.tgz -C /usr/local/bin/
rm -rf consul-template.tgz
