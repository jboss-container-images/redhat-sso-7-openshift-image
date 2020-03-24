#!/bin/bash

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cp $ADDED_DIR/configure_sso_cli_extensions.sh $JBOSS_HOME/bin/launch

