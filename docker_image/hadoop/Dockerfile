ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG HADOOP_VERSION=3.2.1

RUN set -xeu; \
    apt-get update; \
    apt-get install -y libsnappy1v5;

RUN set -xeu; \
    mkdir /tmp/dl; \
    cd /tmp/dl; \
    wget https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz.sha512; \
    sed -i 's#/build/source/target/artifacts/##g' hadoop-${HADOOP_VERSION}.tar.gz.sha512; \
    wget --progress=dot:giga -O hadoop-${HADOOP_VERSION}.tar.gz \
        "https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"; \
    sha512sum -c hadoop-${HADOOP_VERSION}.tar.gz.sha512; \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz; \
    mv hadoop-${HADOOP_VERSION} /opt/hadoop; \
    rm -rf /tmp/dl;

ENV PATH=/opt/hadoop/bin:${PATH}

RUN echo "export HADOOP_CLASSPATH=/opt/alluxio/client/alluxio-*-client.jar:\${HADOOP_CLASSPATH}" >> /opt/hadoop/etc/hadoop/hadoop-env.sh

ENV HADOOP_HOME=/opt/hadoop
