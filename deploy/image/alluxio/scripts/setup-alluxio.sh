#!/usr/bin/env bash
set -xeu

ROLES=$1  # master job_master worker job_worker, space seprated
DATA_DIR=$2
NUMBER_OF_MASTER=$3
UFS_OSS_ACCESS_KEY_ID=$4
UFS_OSS_ACCESS_KEY_SECRET=$5
UFS_OSS_ENDPOINT=$6
UFS_OSS_BUCKET=$7


SERVICE_DIR=/root/services/alluxio
mkdir -p $SERVICE_DIR
cd $SERVICE_DIR

CHECK_HEALTH_SCRIPT=$SERVICE_DIR/check-health.sh

cat <<EOF > $CHECK_HEALTH_SCRIPT
#!/bin/sh
set -ue
role=\$1

date --rfc-3339=seconds
exec docker exec "alluxio_\$role" alluxio-monitor.sh "\$role"
EOF
chmod a+x $CHECK_HEALTH_SCRIPT

cat <<EOF > /etc/sudoers.d/consul-alluxio-health-check
consul ALL=(root) NOPASSWD: $CHECK_HEALTH_SCRIPT
EOF

TAG_LEADER_SCRIPT=$SERVICE_DIR/tag-leader.sh

cat <<EOF > $TAG_LEADER_SCRIPT
#!/bin/sh
set -ue
role=\$1
service_def=\$2

date --rfc-3339=seconds > /dev/stderr

case \$role in
        master)
                tag_name=leader
                get_leader_cmd="alluxio fs leader"
                ;;
        job_master)
                tag_name=job_leader
                get_leader_cmd="alluxio job leader"
                ;;
        *)
                echo "invalid role"
                exit 1
                ;;
esac

leader=\$(docker exec "alluxio_\$role" \$get_leader_cmd)
echo "leader" \$leader > /dev/stderr

if [ "\$leader" = "\$(hostname)" ]; then
        tags="(.service.tags + [\"\$tag_name\"])"
else
        tags="(.service.tags - [\"\$tag_name\"])"
fi


old=\$(cat \$service_def)
new=\$(cat \$service_def | jq "{service: (.service + {tags: \$tags | unique})}")

if [ "\$old" != "\$new" ]; then
        echo "\$new" > \$service_def
        consul reload
fi
EOF
chmod a+x $TAG_LEADER_SCRIPT

cat <<EOF > /etc/sudoers.d/consul-alluxio-tag-leader
consul ALL=(root) NOPASSWD: $TAG_LEADER_SCRIPT
EOF

# register service

SERVICE_DEF=/etc/consul.d/alluxio.json

SERVICE_JSON='{"name": "alluxio", "tags": [], "checks": []}'
python <<EOF
import sys, json

ROLES = "$ROLES".split()
SERVICE_DEF = "$SERVICE_DEF"
CHECK_HEALTH_SCRIPT = "$CHECK_HEALTH_SCRIPT"
TAG_LEADER_SCRIPT = "$TAG_LEADER_SCRIPT"

service = {"name": "alluxio", "tags": [], "checks": []}

service["tags"].extend(ROLES)

service["checks"].extend([
    {
        "name": "alluxio-monitor.sh %s" % role,
        "args": ["sudo", CHECK_HEALTH_SCRIPT, role],
        "interval": "30s",
        "status": "passing"
    } for role in ROLES
])

service["checks"].extend([
    {
        "name": "tag %s leader" % role,
        "args": ["sudo", TAG_LEADER_SCRIPT, role, SERVICE_DEF],
        "interval": "30s",
        "status": "passing"
    } for role in ROLES
    if role in {"master", "job_master"}
])

with open(SERVICE_DEF, "w") as f:
    json.dump({"service": service}, f, indent=2)
EOF

chown consul:consul $SERVICE_DEF
chmod 600 $SERVICE_DEF
consul reload

echo "checking master nodes"
deadline=$(($(date +%s)+60))
while true; do
    count=$(curl -sS localhost:8500/v1/catalog/service/alluxio\?tag=master | jq 'length')
    if [ "$count" -ge "$NUMBER_OF_MASTER" ]; then
        echo "$count master nodes are registered"
        break
    else
        if [ $(date +%s) -ge "$deadline" ]; then
            echo "deadline exceeded for checking master nodes"
            exit 1
        fi
        sleep 1
    fi
done


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
{{ with service "master.alluxio|any" -}}
{{ if eq 1 (len .) -}}
# single master setup
alluxio.master.hostname={{ (index . 0).Node }}
{{ else -}}
# multi master setup
alluxio.master.hostname=$(hostname)
alluxio.master.embedded.journal.addresses={{ range \$index, \$item := . }}{{ if ne 0 \$index}},{{ end }}{{ \$item.Node }}:19200{{ end }}
{{ end }}
{{ else -}}
# cannot found master node, please make sure you have registered this service
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
