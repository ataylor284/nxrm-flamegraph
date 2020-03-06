#!/bin/sh -x

export PROFILE_SECONDS=30
export FLAME_GRAPH_DIR=/opt/ataylor/FlameGraph
export JAVA_HOME=/usr/lib/jvm/java

${SONATYPE_DIR}/start-nexus-repository-manager.sh &

cd /opt
sudo perf record -F 99 -a -g -o perf.data -- sleep $PROFILE_SECONDS 
(cd /opt/ataylor/perf-map-agent/out && java -cp /opt/ataylor/perf-map-agent/out/attach-main.jar:$JAVA_HOME/lib/tools.jar net.virtualvoid.perf.AttachOnce $(cat /opt/sonatype/sonatype-work/nexus3/karaf.pid))
sudo chown root /tmp/perf-*.map
sudo perf script | ${FLAME_GRAPH_DIR}/stackcollapse-perf.pl | ${FLAME_GRAPH_DIR}/flamegraph.pl --color=java --hash --width 2400 > /tmp/flamegraph.svg
