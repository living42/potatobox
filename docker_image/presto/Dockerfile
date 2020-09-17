ARG ALLUXIO_IMAGE

FROM ${ALLUXIO_IMAGE} as alluxio

RUN set -xeu;\
    mkdir /tmp/alluxio-client; \
    cp /opt/alluxio/client/alluxio-*-client.jar /tmp/alluxio-client;

FROM openjdk:11.0.8

ARG PRESTO_VERSION=341

RUN set -xeu; \
    mkdir /tmp/dl; \
    cd /tmp/dl; \
    wget https://repo1.maven.org/maven2/io/prestosql/presto-server/${PRESTO_VERSION}/presto-server-${PRESTO_VERSION}.tar.gz.sha1; \
    echo " presto-server-${PRESTO_VERSION}.tar.gz" >> presto-server-${PRESTO_VERSION}.tar.gz.sha1; \
    wget --progress=dot:giga https://repo1.maven.org/maven2/io/prestosql/presto-server/${PRESTO_VERSION}/presto-server-${PRESTO_VERSION}.tar.gz; \
    sha1sum -c presto-server-${PRESTO_VERSION}.tar.gz.sha1; \
    tar -xzf presto-server-${PRESTO_VERSION}.tar.gz; \
    mv presto-server-${PRESTO_VERSION} /opt/presto; \
    rm -rf /tmp/dl;


RUN set -xeu; \
    apt-get update; \
    apt-get install -y less

RUN set -xeu; \
    mkdir /tmp/dl; \
    cd /tmp/dl; \
    wget https://repo1.maven.org/maven2/io/prestosql/presto-cli/${PRESTO_VERSION}/presto-cli-${PRESTO_VERSION}-executable.jar.sha1; \
    echo " presto-cli-${PRESTO_VERSION}-executable.jar" >> presto-cli-${PRESTO_VERSION}-executable.jar.sha1; \
    wget --progress=dot:mega https://repo1.maven.org/maven2/io/prestosql/presto-cli/${PRESTO_VERSION}/presto-cli-${PRESTO_VERSION}-executable.jar; \
    sha1sum -c presto-cli-${PRESTO_VERSION}-executable.jar.sha1; \
    mv presto-cli-${PRESTO_VERSION}-executable.jar /usr/bin/presto; \
    chmod +x /usr/bin/presto; \
    rm -rf /tmp/dl;

# replace newer version of alluxio-client
COPY --from=alluxio /tmp/alluxio-client/* /opt/presto/plugin/hive-hadoop2/
RUN rm /opt/presto/plugin/hive-hadoop2/alluxio-shaded-client-*.jar
