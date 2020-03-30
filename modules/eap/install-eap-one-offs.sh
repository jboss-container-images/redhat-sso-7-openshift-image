#!/bin/bash

set -e

SOURCES_DIR=/tmp/artifacts/

export JAVA_OPTS="${JAVA_OPTS} -Dorg.wildfly.patching.jar.invalidation=true"

# Do not use for cycle, it would faile if no such files are found
find $SOURCES_DIR -name 'eap-one-off-*.zip' | while read I; do
    echo "Applying patch $I"
    $JBOSS_HOME/bin/jboss-cli.sh --command="patch apply $I"
done
