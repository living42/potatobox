#!/usr/bin/env bash
set -xeu

REGION=$(curl -sS 100.100.100.200/2016-01-01/meta-data/region-id)

setup_server () {
  CONSUL_DATA_DIR=$1
  SERVER_TAGS=$2

  [ -d "$CONSUL_DATA_DIR" ] || {
      mkdir $CONSUL_DATA_DIR
      chown consul:consul $CONSUL_DATA_DIR
  }

  CONSUL_SERVER_ADDRS=$(env HOME=/root aliyun ecs DescribeInstances \
      $SERVER_TAGS \
      | jq '[.Instances.Instance[].VpcAttributes.PrivateIpAddress.IpAddress[0]]')

  BOOTSTRAP_EXPECT=$(echo $CONSUL_SERVER_ADDRS | jq length)

  cat <<EOF > /etc/consul.d/consul.hcl
datacenter = "${REGION}"
data_dir = "${CONSUL_DATA_DIR}"
client_addr = "127.0.0.1 {{ GetInterfaceIP \"eth0\" }}"
ports = {
  "dns" = 53
}
ui = true
server = true
bootstrap_expect = ${BOOTSTRAP_EXPECT}
bind_addr = "{{ GetInterfaceIP \"eth0\" }}"
retry_join = ${CONSUL_SERVER_ADDRS}
enable_local_script_checks = true
EOF

  chown consul:consul /etc/consul.d/consul.hcl
  chmod 600 /etc/consul.d/consul.hcl

  setup_systemd_service
}

setup_client () {
  CONSUL_SERVER_ADDRS=$1

  if [ -d /data ]; then
    CONSUL_DATA_DIR=/data/consul/client
  else
    CONSUL_DATA_DIR=/var/lib/consul/client
  fi

  mkdir -p $CONSUL_DATA_DIR
  chown -R consul:consul $CONSUL_DATA_DIR

  cat <<EOF > /etc/consul.d/consul.hcl
datacenter = "${REGION}"
data_dir = "${CONSUL_DATA_DIR}"
client_addr = "127.0.0.1 {{ GetInterfaceIP \"eth0\" }}"
ports = {
  "dns" = 53
}
server = false
bind_addr = "{{ GetInterfaceIP \"eth0\" }}"
retry_join = ${CONSUL_SERVER_ADDRS}
enable_local_script_checks = true
EOF

  chown consul:consul /etc/consul.d/consul.hcl
  chmod 600 /etc/consul.d/consul.hcl

  setup_systemd_service
}


setup_systemd_service() {
  cat <<EOF > /etc/systemd/system/consul.service
[Unit]
Description=Consul
After=network.target

[Service]
User=consul
ExecStart=/usr/bin/consul agent -config-dir /etc/consul.d
ExecStop=/usr/bin/consul leave
ExecReload=/usr/bin/consul reload
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable consul
  systemctl start consul
}

wait_agent_up() {
  check_deadline=$(($(date +%s) + 60))
  until (consul kv put .test/$(hostname) 1 && consul kv delete .test/$(hostname)); do
    if [ "$(date +%s)" -ge "$check_deadline" ]; then
      echo "consul did not up"
      exit 1
    fi
    echo "waiting consul servers up"
    sleep 1
  done
}

setup_dns_server() {
  # Modify resolv.conf to forward dns lookup into consul, so we can use hostname
  # to communicate each other, further use service name to
  # NOTE this only tested on Debian 10, may no work on other distro
  cat <<EOF >> /etc/resolvconf/resolv.conf.d/head
search node.consul service.consul
nameserver 127.0.0.1
EOF
# overwrite default configuration allow parallel lookups to avoid delay when lookup internet domains
cat <<EOF > /etc/resolvconf/resolv.conf.d/tail
options timeout:2 attempts:3
EOF

  systemctl restart networking
}

TYPE=$1

case $TYPE in
  server)
    setup_server "$2" "$3"
  ;;
  client)
    setup_client "$2"
  ;;
  *)
    echo "invalid TYPE $TYPE"
    exit 1
  ;;
esac

wait_agent_up
setup_dns_server
