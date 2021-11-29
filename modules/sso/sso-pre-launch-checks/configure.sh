#!/bin/bash
set -e

# Import RH-SSO global variables & functions to image build-time
# shellcheck disable=SC1091
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

SCRIPT_DIR=$(dirname "$0")
ADDED_DIR=${SCRIPT_DIR}/added

cp "${ADDED_DIR}/sso_image_pre_launch_checks.sh" "${JBOSS_HOME}/bin/launch"
