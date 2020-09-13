#!/bin/sh
set -xeu

DB_INSTANCE_ID=$1
DB_NAME=$2

SERVICE_DIR=/root/services/hive
mkdir -p $SERVICE_DIR
cd $SERVICE_DIR

ALLUXIO_SERVICE_DIR=$(dirname $SERVICE_DIR)/alluxio

export HOME=/root

DB_USER="metastore_$(hostname)"
DB_PASSWORD="$(head -c 15 /dev/urandom | base32)"

# create account and grant read write access
# NOTE this is bad, we grant too much privilege to this box
# TODO might using Vault to do this
aliyun rds CreateAccount --DBInstanceId=$DB_INSTANCE_ID --AccountName=$DB_USER --AccountPassword=$DB_PASSWORD || {
    echo "reset password"
    aliyun rds ResetAccountPassword --DBInstanceId=$DB_INSTANCE_ID --AccountName=$DB_USER --AccountPassword=$DB_PASSWORD
}
aliyun rds GrantAccountPrivilege --DBInstanceId=$DB_INSTANCE_ID --AccountName=$DB_USER --DBName=$DB_NAME --AccountPrivilege=ReadWrite


# get connection info
CONN_INFO=$(aliyun rds DescribeDBInstanceNetInfo --DBInstanceId=$DB_INSTANCE_ID | jq '.DBInstanceNetInfos.DBInstanceNetInfo | select(.[].IPType=="Private") | .[0]')

DB_HOST=$(echo "$CONN_INFO" | jq -r .ConnectionString)
DB_PORT=$(echo "$CONN_INFO" | jq -r .Port)


cat <<EOF > hive-site-private.xml
<configuration>
  <property>
    <name>hive.metastore.uris</name>
    <value>thrift://$(hostname):9083</value>
  </property>
  <property>
    <name>hive.metastore.warehouse.dir</name>
    <value>alluxio:///</value>
  </property>
  <property>
    <name>hive.metastore.db.type</name>
    <value>mysql</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>com.mysql.cj.jdbc.Driver</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:mysql://$DB_HOST:$DB_PORT/$DB_NAME</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>$DB_USER</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>$DB_PASSWORD</value>
  </property>
</configuration>
EOF


# TODO move core-site.xml into hadoop service's dir
cat <<EOF > core-site.xml
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

cat <<EOF > docker-compose.yaml
version: "3.8"
services:
  hive_metastore:
    image: hive
    container_name: hive_metastore
    network_mode: host
    volumes:
      - /var/lib/hive:/var/lib/hive
      - /var/log/hive:/var/log/hive
      - /var/log/alluxio:/var/log/alluxio
      - ./hive-site-private.xml:/opt/hive/conf/hive-site.xml:ro
      - ./core-site.xml:/opt/hadoop/etc/hadoop/core-site.xml:ro
      - ${ALLUXIO_SERVICE_DIR}/alluxio-site.properties:/opt/alluxio/conf/alluxio-site.properties:ro
    command: hive --service metastore
    restart: unless-stopped
EOF

docker-compose --no-ansi run --rm hive_metastore bash -c "schematool -dbType mysql -upgradeSchema || schematool -dbType mysql -initSchema"

docker-compose up -d hive_metastore
