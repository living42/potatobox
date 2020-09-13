#!/usr/bin/env bash
set -xeu

SERVICE_DIR=/root/services/alluxio
mkdir -p $SERVICE_DIR
cd $SERVICE_DIR

SERVICE_NAME=alluxio

echo "checking master nodes"
deadline=$(($(date +%s)+180))
while true; do
    # make sure alluxio cluster is live by check there has leader elected
    count=$(curl -sS localhost:8500/v1/catalog/service/$SERVICE_NAME\?tag=leader | jq length)
    if [ "$count" -ge "1" ]; then
        echo "leader is alive"
        break
    else
        if [ $(date +%s) -ge "$deadline" ]; then
            echo "deadline exceeded for checking master nodes"
            exit 1
        fi
        sleep 5
    fi
done

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

consul-template --once \
    --template 'alluxio-site.properties.tpl:alluxio-site.properties'
