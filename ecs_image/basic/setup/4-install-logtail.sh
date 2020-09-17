#!/bin/sh
set -xeu

## delay installcation on instance first launch
echo '#!/bin/sh
region_id=$(curl 100.100.100.200/2016-01-01/meta-data/region-id)
wget http://logtail-release-${region_id}.oss-${region_id}-internal.aliyuncs.com/linux64/logtail.sh -O logtail.sh; chmod 755 logtail.sh; ./logtail.sh install ${region_id}
rm logtail.sh
' > /var/lib/cloud/scripts/per-instance/install_logtail.sh
chmod +x /var/lib/cloud/scripts/per-instance/install_logtail.sh
