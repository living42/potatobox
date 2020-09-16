ARG BASE_IMAGE

FROM ${BASE_IMAGE}

ARG HIVE_VERSION=2.3.7

RUN set -xeu; \
    mkdir /tmp/dl; \
    cd /tmp/dl; \
    wget https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256; \
    wget --progress=dot:giga -O apache-hive-${HIVE_VERSION}-bin.tar.gz \
        "https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz"; \
    sha256sum -c apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256; \
    tar -xzf apache-hive-${HIVE_VERSION}-bin.tar.gz; \
    mv apache-hive-${HIVE_VERSION}-bin /opt/hive; \
    rm -rf /tmp/dl;

ENV PATH=/opt/hive/bin:${PATH}

# https://issues.apache.org/jira/browse/HIVE-22915
RUN rm /opt/hive/lib/guava-*.jar && cp /opt/hadoop/share/hadoop/hdfs/lib/guava-27.0-jre.jar /opt/hive/lib/

RUN set -xeu; \
    cd /opt/hive/lib; \
    wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.21/mysql-connector-java-8.0.21.jar;

# redirect logs to /var/log/hive
RUN set -xeu; \
    cd /opt/hive/conf; \
    for template in `ls *log4j2.properties.template`; do \
        cp $template ${template%.template}; \
        sed -i 's#property.hive.log.dir.*#property.hive.log.dir = /var/log/hive/${sys:user.name}#g' ${template%.template}; \
    done;
