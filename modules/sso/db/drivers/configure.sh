#!/bin/bash
# Link DB drivers, provided by RPM packages, into the "openshift" layer
set -e

# Import RH-SSO global variables & functions to image build-time
# shellcheck disable=SC1091
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

SCRIPT_DIR=$(dirname "$0")
ADDED_DIR=${SCRIPT_DIR}/added

function link {
  mkdir -p "$(dirname "$2")"
  ln -s "$1" "$2"
}

# Link the main PostgreSQL JDBC JAR
link /usr/share/java/postgresql-jdbc.jar "${JBOSS_HOME}"/modules/system/layers/openshift/org/postgresql/main/postgresql-jdbc.jar
# CIAM-1495: But also the JARs for the Ongres SCRAM library, so it's possible to use SCRAM-SHA-256 password-based auth method
link /usr/share/java/ongres-scram/common.jar "${JBOSS_HOME}"/modules/system/layers/openshift/com/ongres/scram/common/main/ongres-scram-common.jar
link /usr/share/java/ongres-scram/client.jar "${JBOSS_HOME}"/modules/system/layers/openshift/com/ongres/scram/client/main/ongres-scram-client.jar

# Remove any existing destination files first (which might be symlinks)
cp -rp --remove-destination "${ADDED_DIR}/modules" "${JBOSS_HOME}"
