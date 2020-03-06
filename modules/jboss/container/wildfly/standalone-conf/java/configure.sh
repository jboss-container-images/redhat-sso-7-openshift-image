#!/bin/sh
set -e

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cat ${ADDED_DIR}/standalone.conf >> $JBOSS_HOME/bin/standalone.conf
