#!/bin/sh

set -e

SCRIPT_DIR=$(dirname "$0")
ADDED_DIR=${SCRIPT_DIR}/added

cp "${ADDED_DIR}/standalone-openshift.xml" "${JBOSS_HOME}/standalone/configuration"
cp "${ADDED_DIR}/import-realm.json" "${JBOSS_HOME}/standalone/configuration"
cp "${ADDED_DIR}/openshift-launch.sh" "${ADDED_DIR}/openshift-migrate.sh" "${JBOSS_HOME}/bin/"

mkdir -p "${JBOSS_HOME}/bin/launch"
# Intentionally keep the asterisk (*) character in the next statement outside
# of the double quotes to achieve proper globbing / expansion to all applicable
# scripts
cp -r "${ADDED_DIR}"/launch/* "${JBOSS_HOME}/bin/launch"

# KEYCLOAK-13585 Since using nss_wrapper, modifications of system's /etc/passwd
# file when container is run using an arbitrary assigned UID aren't neither
# needed nor expected anymore. Delete the unused 'passwd.sh' script to quieten
# a permission denied warning trying to modify /etc/passwd when container is run
# using an arbitrary assigned UID. But that permission denied is actually
# expected since the default permissions of /etc/passwd file weren't changed
rm -rf "${JBOSS_HOME}/bin/launch/passwd.sh"

mkdir "${JBOSS_HOME}/root-app-redirect"
cp "${ADDED_DIR}/index.html" "${JBOSS_HOME}/root-app-redirect"
rm -rf "${JBOSS_HOME}/welcome-content"

chown -R jboss:root "${JBOSS_HOME}"
chmod -R g+rwX "${JBOSS_HOME}"
