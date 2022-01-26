#!/bin/bash

set -e

readonly SOURCES_DIR="/tmp/artifacts/"
export JAVA_OPTS="${JAVA_OPTS} -Dorg.wildfly.patching.jar.invalidation=true"

# Do not use for cycle, it would faile if no such files are found
find "${SOURCES_DIR}" \( -name 'eap-one-off-*.zip' -o -name 'rh-sso-*.zip' \) | while read -r I; do
    echo "Applying patch: '$I' ..."
    # CIAM-1975 Prevent any possible 'Conflicts detected:' error while applying
    # the patch by using the '--override-all' option of patch apply command
    "${JBOSS_HOME}"/bin/jboss-cli.sh --command="patch apply $I --override-all"
done
