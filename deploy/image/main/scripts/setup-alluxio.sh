#!/usr/bin/env bash
set -xeu

ROLES=$1  # master job_master worker job_worker, space seprated
DATA_DIR=$2
NUMBER_OF_MASTER=$3
UFS_OSS_ACCESS_KEY_ID=$4
UFS_OSS_ACCESS_KEY_SECRET=$5
UFS_OSS_ENDPOINT=$6
UFS_OSS_BUCKET=$7

# register service

# TODO register checks

for role in $ROLES; do
    case $role in
        master | job_master | worker| job_worker)
        ;;
        *)
        echo "Unknown role $role to provision"
        exit 1
        ;;
    esac

    SERVICE_DEF=/etc/consul.d/alluxio_${role}.json
    cat <<EOF > ${SERVICE_DEF}
{
    "service": {
        "name": "alluxio_${role}"
    }
}
EOF
    chown consul:consul $SERVICE_DEF
    chmod 600 $SERVICE_DEF
done

consul reload

echo "checking alluxio_master service"
deadline=$(($(date +%s)+30))
while true; do
    count=$(consul catalog nodes -service alluxio_master | awk 'NR!=1{print $1}' | wc -l)
    if [ "$count" -ge "$NUMBER_OF_MASTER" ]; then
        echo "$count alluxio_master are registered"
        break
    else
        if [ $(date +%s) -ge "$deadline" ]; then
            echo "deadline exceeded for checking alluxio_master service"
            exit 1
        fi
        sleep 1
    fi
done

SERVICE_DIR=/root/services/alluxio
mkdir -p $SERVICE_DIR
cd $SERVICE_DIR


cat <<EOF > docker-compose.yaml
version: "3.8"
services:
EOF

for role in $ROLES; do
    case $role in
        master | job_master | worker| job_worker)
        ;;
        *)
        echo "Unknown role $role to provision"
        exit 1
        ;;
    esac

    cat <<EOF >> docker-compose.yaml
  ${role}:
    image: alluxio
    container_name: alluxio_${role}
    network_mode: host
    volumes:
      - ${DATA_DIR}:/var/lib/alluxio
      - /var/log/alluxio:/var/log/alluxio
      - ./alluxio-site-private.properties:/opt/alluxio/conf/alluxio-site.properties
    command:
      - bash
      - -c
      - |
        trap 'alluxio-stop.sh ${role}' EXIT
        alluxio-start.sh -w ${role} &
        wait
    stop_grace_period: 1m
    restart: unless-stopped
EOF
done

# we render to separate alluxio-site.properties, one is used by alluxio
# internally, it's named alluxio-site-private.properties. it may contain
# sensitive infomation needed to run alluxio service. the second one is for
# those who integrated with alluxio client (like Spark, Presto), it's
# named alluxio-site.properties. this one contains only necessary options to
# run alluxio client (will, at least don't put any sensitive data in here)

cat <<EOF > alluxio-site.properties.tpl
{{ with service "alluxio_master|any" -}}
{{ if eq 1 (len .) -}}
# single master setup
alluxio.master.hostname={{ (index . 0).Node }}
{{ else -}}
# multi master setup
alluxio.master.hostname=$(hostname)
alluxio.master.embedded.journal.addresses={{ range \$index, \$item := . }}{{ if ne 0 \$index}},{{ end }}{{ \$item.Node }}:19200{{ end }}
{{ end }}
{{ else -}}
# cannot found alluxio_master service, please make sure you have registered this service
{{ end -}}

alluxio.worker.tieredstore.level0.alias=SSD
alluxio.worker.tieredstore.level0.dirs.path=/var/lib/alluxio/data
alluxio.worker.tieredstore.level0.dirs.quota=5G

alluxio.user.short.circuit.preferred=true
alluxio.user.metrics.collection.enabled=true
alluxio.user.file.writetype.default=CACHE_THROUGH

EOF

cat <<EOF > alluxio-site-private.properties.tpl
{{ file "alluxio-site.properties" }}

alluxio.master.journal.type=EMBEDDED
alluxio.master.journal.folder=/var/lib/alluxio/journal
alluxio.master.metastore=ROCKS
alluxio.master.metastore.dir=/var/lib/alluxio/metastore
alluxio.master.metastore.inode.cache.max.size=500000

alluxio.security.authorization.permission.enabled=false
alluxio.security.login.impersonation.username=_NONE_

alluxio.master.mount.table.root.ufs=oss://${UFS_OSS_BUCKET}
fs.oss.accessKeyId=${UFS_OSS_ACCESS_KEY_ID}
fs.oss.accessKeySecret=${UFS_OSS_ACCESS_KEY_SECRET}
fs.oss.endpoint=${UFS_OSS_ENDPOINT}
EOF

# need render public config first to make sure private renders correct result
consul-template --once \
    --template 'alluxio-site.properties.tpl:alluxio-site.properties'

consul-template --once \
    --template 'alluxio-site-private.properties.tpl:alluxio-site-private.properties'

if echo $ROLES | grep -q -E '\bmaster\b'; then
    # check journal and run formatJournal when it's not created
    if [ ! -d $DATA_DIR/journal ]; then
        docker-compose run --rm master alluxio formatJournal
    else
        echo "journal already exists"
    fi
fi

docker-compose up -d --remove-orphans
