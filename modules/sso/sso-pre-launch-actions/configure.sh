#!/bin/bash
set -eu

# Import RH-SSO global variables & functions to image build-time
# shellcheck disable=SC1091
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

# CIAM-1757: On each arch remove JDK 1.8 rpms if present (since using JDK 11 already)
rpm --query --all name=java* version=1.8.0* | xargs rpm -e --nodeps