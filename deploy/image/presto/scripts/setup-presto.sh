#!/bin/sh
set -xeu

ROLE=$1  # coordinator or worker
ALLUXIO_DATA_DIR=$2

SERVICE_DEF=/etc/consul.d/presto.json

cat <<EOF > $SERVICE_DEF
{
  "service": {
    "name": "presto",
    "tags": ["${ROLE}"],
    "checks": [
      {
        "name": "Presto 8080 Port",
        "http": "http://localhost:8080/v1/info",
        "method": "GET",
        "interval": "10s",
        "timeout": "1s"
      }
    ]
  }
}
EOF
chown consul:consul $SERVICE_DEF
chmod 600 $SERVICE_DEF
consul reload

SERVICE_DIR=/root/services/presto
mkdir -p $SERVICE_DIR
cd $SERVICE_DIR

ALLUXIO_SERVICE_DIR=$(dirname $SERVICE_DIR)/alluxio


HIVE_SERVICE_DIR=$(dirname $SERVICE_DIR)/hive
mkdir -p $HIVE_SERVICE_DIR

cat <<EOF > $HIVE_SERVICE_DIR/hive-site.xml
<configuration>
  <property>
    <name>hive.metastore.uris</name>
    <value>thrift://metastore.hive.service.consul:9083</value>
  </property>
</configuration>
EOF


HADOOP_SERVICE_DIR=$(dirname $SERVICE_DIR)/hadoop
mkdir -p $HADOOP_SERVICE_DIR

cat <<EOF > $HADOOP_SERVICE_DIR/core-site.xml
<configuration>
  <property>
    <name>fs.alluxio.impl</name>
    <value>alluxio.hadoop.FileSystem</value>
  </property>
  <property>
    <name>fs.defaultFS</name>
    <value>alluxio:///</value>
  </property>
</configuration>
EOF


mkdir conf

# config.properties

case $ROLE in
  coordinator)
    cat <<EOF > conf/config.properties
coordinator=true
node-scheduler.include-coordinator=false
discovery-server.enabled=true
EOF
  ;;
  worker)
    cat <<EOF > conf/config.properties
coordinator=false
EOF
  ;;
  *)
    echo "invalid role $ROLE"
    exit 1
  ;;
esac
cat <<EOF >> conf/config.properties
discovery.uri=http://coordinator.presto.service.consul:8080
http-server.http.port=8080
query.max-memory=512MB
query.max-memory-per-node=512MB
query.max-total-memory-per-node=512MB
EOF

#  jvm.config

cat <<EOF > conf/jvm.config
-server
-XX:-UseBiasedLocking
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:+ExitOnOutOfMemoryError
-XX:+HeapDumpOnOutOfMemoryError
-XX:ReservedCodeCacheSize=512M
-Djdk.attach.allowAttachSelf=true
-Djdk.nio.maxCachedBufferSize=2000000
-Xbootclasspath/a:/opt/alluxio/conf/alluxio-site.properties
EOF

# log.properties

cat <<EOF > conf/log.properties
io.prestosql=INFO
EOF

# node.properties

INSTANCE_ID=$(curl -sS 100.100.100.200/2016-01-01/meta-data/instance-id)
cat <<EOF > conf/node.properties
node.environment=local
node.id=$INSTANCE_ID
node.data-dir=/var/lib/presto
EOF

mkdir -p conf/catalog

# catalog/hive.properties

cat <<EOF > conf/catalog/hive.properties
connector.name=hive-hadoop2
hive.metastore.uri=thrift://metastore.hive.service.consul:9083
hive.config.resources=/opt/hadoop/etc/hadoop/core-site.xml
hive.security=legacy
hive.allow-drop-table=true
EOF

# catalog/jmx.properties

cat <<EOF > conf/catalog/jmx.properties
connector.name=jmx
EOF

# catalog/tpcds.properties

cat <<EOF > conf/catalog/tpcds.properties
connector.name=tpcds
EOF

# catalog/tpch.properties

cat <<EOF > conf/catalog/tpch.properties
connector.name=tpch
EOF


cat <<EOF > docker-compose.yaml
version: "3.8"
services:
  presto:
    image: presto
    container_name: presto
    network_mode: host
    volumes:
      - ./conf:/opt/presto/etc:ro
      - /var/lib/presto:/var/lib/presto
      - /var/log/alluxio:/var/log/alluxio
      - ${ALLUXIO_DATA_DIR}:/var/lib/alluxio
      - ${HIVE_SERVICE_DIR}/hive-site.xml:/opt/hive/conf/hive-site.xml:ro
      - ${HADOOP_SERVICE_DIR}/core-site.xml:/opt/hadoop/etc/hadoop/core-site.xml:ro
      - ${ALLUXIO_SERVICE_DIR}/alluxio-site.properties:/opt/alluxio/conf/alluxio-site.properties:ro
    command: /opt/presto/bin/launcher run
    restart: unless-stopped
EOF

docker-compose up -d
