
FROM fedora:26

ARG ZOOKEEPER_VERSION=3.4.10
ARG HADOOP_VERSION=2.8.0
ARG ACCUMULO_VERSION=1.8.1

RUN echo -e "\n* soft nofile 65536\n* hard nofile 65536" >> /etc/security/limits.conf

RUN dnf install -y tar
RUN dnf install -y java-1.8.0-openjdk
RUN dnf install -y procps-ng hostname
RUN dnf install -y which
# Aditional dependencies
RUN dnf install -y wget
RUN dnf install -y maven

# Download requested version
ARG HADOOP_HASH
ARG ZOOKEEPER_HASH
ARG ACCUMULO_HASH

ENV HADOOP_VERSION ${HADOOP_VERSION:-2.8.0}
ENV ZOOKEEPER_VERSION ${ZOOKEEPER_VERSION:-3.4.10}
ENV ACCUMULO_VERSION ${ACCUMULO_VERSION:-1.8.1}

ENV HADOOP_HASH ${HADOOP_HASH:-f754062ab08b3f24ed4fb5a0ec5367352d399523}
ENV ZOOKEEPER_HASH ${ZOOKEEPER_HASH:-eb2145498c5f7a0d23650d3e0102318363206fba}
ENV ACCUMULO_HASH ${ACCUMULO_HASH:-8e6b4f5d9bd0c41ca9a206e876553d8b39923528}

# Download from Apache mirrors instead of archive #9
ENV APACHE_DIST_URLS \
  https://www.apache.org/dyn/closer.cgi?action=download&filename= \
# if the version is outdated (or we're grabbing the .asc file), we might have to pull from the dist/archive :/
  https://www-us.apache.org/dist/ \
  https://www.apache.org/dist/ \
https://archive.apache.org/dist/

RUN set -eux; \
  download_bin() { \
    local f="$1"; shift; \
    local hash="$1"; shift; \
    local distFile="$1"; shift; \
    local success=; \
    local distUrl=; \
    for distUrl in $APACHE_DIST_URLS; do \
      if wget -nv -O "$f" "$distUrl$distFile"; then \
        success=1; \
        # Checksum the download
        echo "$hash" "*$f" | sha1sum -c -; \
        break; \
      fi; \
    done; \
    [ -n "$success" ]; \
  };\
   \
   download_bin "accumulo.tar.gz" "$ACCUMULO_HASH" "accumulo/$ACCUMULO_VERSION/accumulo-$ACCUMULO_VERSION-bin.tar.gz"; \
   download_bin "hadoop.tar.gz" "$HADOOP_HASH" "hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz"; \
   download_bin "zookeeper.tar.gz" "$ZOOKEEPER_HASH" "zookeeper/zookeeper-$ZOOKEEPER_VERSION/zookeeper-$ZOOKEEPER_VERSION.tar.gz"

RUN tar xzf accumulo.tar.gz -C /tmp/
RUN tar xzf hadoop.tar.gz -C /tmp/
RUN tar xzf zookeeper.tar.gz -C /tmp/

RUN rm accumulo.tar.gz 
RUN rm hadoop.tar.gz 
RUN rm zookeeper.tar.gz 

RUN mv /tmp/hadoop-$HADOOP_VERSION /usr/local/hadoop-$HADOOP_VERSION
RUN mv /tmp/zookeeper-$ZOOKEEPER_VERSION /usr/local/zookeeper-$ZOOKEEPER_VERSION
RUN mv /tmp/accumulo-$ACCUMULO_VERSION /usr/local/accumulo-$ACCUMULO_VERSION

# hadoop
# ADD hadoop-${HADOOP_VERSION}.tar.gz /usr/local/
RUN ln -s /usr/local/hadoop-${HADOOP_VERSION} /usr/local/hadoop

# Zookeeper
# ADD zookeeper-${ZOOKEEPER_VERSION}.tar.gz /usr/local/
RUN ln -s /usr/local/zookeeper-${ZOOKEEPER_VERSION} /usr/local/zookeeper

# Accumulo
# ADD accumulo-${ACCUMULO_VERSION}-bin.tar.gz /usr/local/
RUN ln -s /usr/local/accumulo-${ACCUMULO_VERSION} /usr/local/accumulo

# Diagnostic tools :/
RUN dnf install -y net-tools
RUN dnf install -y telnet

ENV ACCUMULO_HOME /usr/local/accumulo
ENV PATH $PATH:$ACCUMULO_HOME/bin
ADD accumulo/* $ACCUMULO_HOME/conf/

ADD start-accumulo /start-accumulo
ADD start-process /start-process

RUN rm -rf /var/lib/apt/lists/*

CMD /start-accumulo

EXPOSE 9000 50095 42424 9995 9997

