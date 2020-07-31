#!/bin/sh
set -e

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added
SOURCES_DIR="/tmp/artifacts"

. $JBOSS_HOME/bin/launch/files.sh

cp -p ${ADDED_DIR}/launch/elytron.sh ${JBOSS_HOME}/bin/launch/
chmod ug+x ${JBOSS_HOME}/bin/launch/elytron.sh


