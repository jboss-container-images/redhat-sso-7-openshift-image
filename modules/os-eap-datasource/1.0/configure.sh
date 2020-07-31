#!/bin/sh
# Openshift EAP datasource-common script package
set -e

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p ${JBOSS_HOME}/bin/launch
cp -r ${ADDED_DIR}/launch/* ${JBOSS_HOME}/bin/launch
