# Copyright (c) 2016-present Sonatype, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM centos:centos7

LABEL vendor=Sonatype \
      maintainer="Sonatype <cloud-ops@sonatype.com>" \
      com.sonatype.license="Apache License, Version 2.0" \
      com.sonatype.name="Nexus Repository Manager base image"

ARG NEXUS_VERSION=3.21.1-01
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz
ARG NEXUS_DOWNLOAD_SHA256_HASH=aa5396eea6e619c32644a25a0225e55d43d8dc1e3567b7042a384a721d56332b

# configure nexus runtime
ENV SONATYPE_DIR=/opt/sonatype
ENV NEXUS_HOME=${SONATYPE_DIR}/nexus \
    NEXUS_DATA=/nexus-data \
    NEXUS_CONTEXT='' \
    SONATYPE_WORK=${SONATYPE_DIR}/sonatype-work \
    DOCKER_TYPE='rh-docker'

ARG NEXUS_REPOSITORY_MANAGER_COOKBOOK_VERSION="release-0.5.20190212-155606.d1afdfe"
ARG NEXUS_REPOSITORY_MANAGER_COOKBOOK_URL="https://github.com/sonatype/chef-nexus-repository-manager/releases/download/${NEXUS_REPOSITORY_MANAGER_COOKBOOK_VERSION}/chef-nexus-repository-manager.tar.gz"

ADD solo.json.erb /var/chef/solo.json.erb

# Install using chef-solo
# Chef version locked to avoid needing to accept the EULA on behalf of whomever builds the image
RUN yum install -y --disableplugin=subscription-manager hostname procps \
    && curl -L https://www.getchef.com/chef/install.sh | bash -s -- -v 14.12.9 \
    && /opt/chef/embedded/bin/erb /var/chef/solo.json.erb > /var/chef/solo.json \
    && chef-solo \
       --recipe-url ${NEXUS_REPOSITORY_MANAGER_COOKBOOK_URL} \
       --json-attributes /var/chef/solo.json \
    && rpm -qa *chef* | xargs rpm -e \
    && rm -rf /etc/chef \
    && rm -rf /opt/chefdk \
    && rm -rf /var/cache/yum \
    && rm -rf /var/chef \
    && yum clean all

# install stuff for building perf-map-agent and sudo for running perf stuff as root
RUN yum install -y --disableplugin=subscription-manager perf cmake make git gcc gcc-c++ sudo

# build perf-map-agent
RUN mkdir -p /opt/ataylor \
    && cd /opt/ataylor \
    && export JAVA_HOME=/usr/lib/jvm/java \
    && git clone --depth=1 https://github.com/jrudolph/perf-map-agent \
    && cd perf-map-agent \
    && cmake . \
    && make

# grab FlameGraph
RUN cd /opt/ataylor \
    && git clone --depth=1 https://github.com/brendangregg/FlameGraph

# configure sudo to allow user nexus to do stuff as root; WARNING: insecure!
RUN echo "nexus ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/user \
     && chmod 0440 /etc/sudoers.d/user

# script to run nexus while perf is recording
COPY --chown=nexus run.sh /opt/run.sh

EXPOSE 8081
USER nexus

# add usual flags plus -XX:+PreserveFramePointer for perf-map-agent
ENV INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs -XX:+PreserveFramePointer"

CMD ["sh", "-c", "/opt/run.sh"]
