ARG ALLUXIO_IMAGE
ARG BASE_IMAGE

FROM ${ALLUXIO_IMAGE} as alluxio

RUN set -xeu;\
    mkdir /tmp/alluxio-client; \
    cp /opt/alluxio/client/alluxio-*-client.jar /tmp/alluxio-client;

FROM ${BASE_IMAGE}

ARG SPARK2_VERSION=2.4.7

RUN set -xeu; \
    mkdir /tmp/dl; \
    cd /tmp/dl; \
    wget https://archive.apache.org/dist/spark/spark-${SPARK2_VERSION}/spark-${SPARK2_VERSION}-bin-without-hadoop.tgz.sha512; \
    wget --progress=dot:giga -O spark-${SPARK2_VERSION}-bin-without-hadoop.tgz \
        "https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=spark/spark-${SPARK2_VERSION}/spark-${SPARK2_VERSION}-bin-without-hadoop.tgz"; \
    gpg --print-md SHA512 spark-${SPARK2_VERSION}-bin-without-hadoop.tgz | diff - spark-${SPARK2_VERSION}-bin-without-hadoop.tgz.sha512; \
    tar -xzf spark-${SPARK2_VERSION}-bin-without-hadoop.tgz; \
    mv spark-${SPARK2_VERSION}-bin-without-hadoop /opt/spark; \
    rm -rf /tmp/dl

ARG SPARK3_VERSION=3.0.1

RUN set -xeu; \
    mkdir /tmp/dl; \
    cd /tmp/dl; \
    wget https://archive.apache.org/dist/spark/spark-${SPARK3_VERSION}/spark-${SPARK3_VERSION}-bin-without-hadoop.tgz.sha512; \
    wget --progress=dot:giga -O spark-${SPARK3_VERSION}-bin-without-hadoop.tgz \
        "https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=spark/spark-${SPARK3_VERSION}/spark-${SPARK3_VERSION}-bin-without-hadoop.tgz"; \
    gpg --print-md SHA512 spark-${SPARK3_VERSION}-bin-without-hadoop.tgz | diff - spark-${SPARK3_VERSION}-bin-without-hadoop.tgz.sha512; \
    tar -xzf spark-${SPARK3_VERSION}-bin-without-hadoop.tgz; \
    mv spark-${SPARK3_VERSION}-bin-without-hadoop /opt/spark3; \
    rm -rf /tmp/dl

# THIS IS TEMPORARY SOLUTION
# Install master branch of Apache Hudi, for alluxio filesystem support
# we use jitpack.io to get the artifact from specific commit
ARG HUDI_COMMIT_ID=0cb24e4a2defd8e639437b6cd145a26f038ef1af
RUN set -xeu; \
    echo ping jitpack to build specific version by commit id; \
    wget -O /dev/null https://jitpack.io/com/github/apache/hudi/hudi-spark-bundle_2.11/${HUDI_COMMIT_ID}/hudi-spark-bundle_2.11-${HUDI_COMMIT_ID}.pom; \
    echo downloading hudi-spark-bundle_2.11; \
    mkdir -p /opt/hudi/hudi-spark-bundle_2.11; \
    wget --progress=dot:mega https://jitpack.io/com/github/apache/hudi/hudi-spark-bundle_2.11/${HUDI_COMMIT_ID}/hudi-spark-bundle_2.11-${HUDI_COMMIT_ID}.jar \
        -O /opt/hudi/hudi-spark-bundle_2.11/hudi-spark-bundle_2.11-${HUDI_COMMIT_ID}.jar

# set spark spark2 as default
ENV PATH=/opt/spark/bin:${PATH}

RUN set -xeu; \
    echo "export SPARK_DIST_CLASSPATH=/opt/hudi/hudi-spark-bundle_2.11/*:\$(hadoop classpath)" >> /opt/spark/conf/spark-env.sh; \
    echo "export LD_LIBRARY_PATH=\$HADOOP_HOME/lib/native/:\$LD_LIBRARY_PATH" >> /opt/spark/conf/spark-env.sh; \
    \
    echo "export SPARK_DIST_CLASSPATH=\$(hadoop classpath)" >> /opt/spark3/conf/spark-env.sh; \
    echo "export LD_LIBRARY_PATH=\$HADOOP_HOME/lib/native/:\$LD_LIBRARY_PATH" >> /opt/spark3/conf/spark-env.sh
