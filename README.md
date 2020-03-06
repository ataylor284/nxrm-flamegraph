NRXM Flamegraph
===============

A simple docker setup to generate flame graphs running NXRM.

Background
----------

Flame graphs provide a visualization of CPU usage over time.  They can
be generated with linux perf profiling framework plus FlameGraph.  The
perf-map-agent with some JVM flags can be used to show Java symbols
directly in the graph.

* https://netflixtechblog.com/java-in-flames-e763b3d32166
* http://www.brendangregg.com/flamegraphs.html
* https://github.com/jrudolph/perf-map-agent

This dockerfile can create a docker container to set up the required
bits, start the profiler, run NXRM, and finally generate the graph.

The graph can be exracted from the container after the run completes
with `docker cp`.

Usage:

    docker build --rm=true --tag=sonatype/nexus3 .
    docker run -d -p 8081:8081 --name nexus --cap-add ALL sonatype/nexus3
    docker cp nexus:/tmp/flamegraph.svg .

