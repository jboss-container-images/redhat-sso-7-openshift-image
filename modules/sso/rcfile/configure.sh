#!/bin/bash
set -e

# Configure module
SCRIPT_DIR="$(dirname "$0")"
# Final destination of the rcfile script within the container image
readonly RC_SCRIPT_DEST="${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

# Create empty JBOSS_HOME/bin/launch directory needed to install module content
mkdir -p "${JBOSS_HOME}/bin/launch"

# Install & configure the rcfile definitions file
cp "${SCRIPT_DIR}/sso-rcfile-definitions.sh" "${RC_SCRIPT_DEST}"
# The 'jboss' user doesn't exist yet. Use his future numeric UID instead
chown 185:root "${RC_SCRIPT_DEST}"
chmod ug+rwX "${RC_SCRIPT_DEST}"

# Import RH-SSO global variables & functions to image build-time
# shellcheck disable=SC1091
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"
