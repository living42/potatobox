#!/usr/bin/env bash
set -xeu

launcher="docker-compose --no-ansi run --rm metastore"
docker-compose ps | grep metastore | grep --silent Up && {
    launcher="docker-compose --no-ansi exec metastore"
}

DB_TYPE=$($launcher bash -c "tr '\n'  ' ' < /opt/hive/conf/hive-site.xml \
    | sed -n -E 's#.*<name>hive.metastore.db.type</name>\s*?<value>(\w+?)</value>.*#\1#p' \
    | tr '[:upper:]' '[:lower:]'")

[ "$DB_TYPE" = "derby" ] && {
docker-compose rm -s -f
    launcher="docker-compose --no-ansi run --rm metastore"
}

$launcher schematool -dbType $DB_TYPE -upgradeSchema || {
    $launcher schematool -dbType $DB_TYPE -initSchema
}
