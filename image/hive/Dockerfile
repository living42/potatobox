ARG BASE_IMAGE

FROM ${BASE_IMAGE}

ARG HIVE_VERSION
ARG APACHE_DIST_MIRROR

RUN set -xeu; \
    mkdir /tmp/dl; \
    cd /tmp/dl; \
    wget https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256; \
    wget --progress=dot:giga ${APACHE_DIST_MIRROR}/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz; \
    sha256sum -c apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256; \
    tar -xzf apache-hive-${HIVE_VERSION}-bin.tar.gz; \
    mv apache-hive-${HIVE_VERSION}-bin /opt/hive; \
    rm -rf /tmp/dl;

ENV PATH=/opt/hive/bin:${PATH}

# https://issues.apache.org/jira/browse/HIVE-22915
RUN rm /opt/hive/lib/guava-19.0.jar && cp /opt/hadoop/share/hadoop/hdfs/lib/guava-27.0-jre.jar /opt/hive/lib/

# redirect logs to /var/log/hive
RUN set -xeu; \
    cd /opt/hive/conf; \
    for template in `ls *log4j2.properties.template`; do \
        cp $template ${template%.template}; \
        sed -i 's#property.hive.log.dir.*#property.hive.log.dir = /var/log/hive/${sys:user.name}#g' ${template%.template}; \
    done;
