#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$0")
ADDED_DIR=${SCRIPT_DIR}/added

cp "${ADDED_DIR}/sso_image_pre_launch_checks.sh" "${JBOSS_HOME}/bin/launch"
