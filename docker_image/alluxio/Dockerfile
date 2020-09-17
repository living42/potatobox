FROM openjdk:8u265

ARG ALLUXIO_VERSION=2.3.0

RUN set -xeu; \
    mkdir /tmp/dl; \
    cd /tmp/dl; \
    wget https://downloads.alluxio.io/downloads/files/${ALLUXIO_VERSION}/alluxio-${ALLUXIO_VERSION}-bin.tar.gz.md5; \
    wget --progress=dot:giga https://downloads.alluxio.io/downloads/files/${ALLUXIO_VERSION}/alluxio-${ALLUXIO_VERSION}-bin.tar.gz; \
    md5sum -c alluxio-${ALLUXIO_VERSION}-bin.tar.gz.md5; \
    tar -xzf alluxio-${ALLUXIO_VERSION}-bin.tar.gz; \
    mv alluxio-${ALLUXIO_VERSION} /opt/alluxio; \
    rm -rf /tmp/dl;

ENV PATH=/opt/alluxio/bin:${PATH}

ENV ALLUXIO_LOGS_DIR=/var/log/alluxio
