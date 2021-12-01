#!/bin/sh
set -eu

# Import RH-SSO global variables & functions to image build-time
# shellcheck disable=SC1091
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

## Work around OpenJDK being installed as dependency. https://bugzilla.redhat.com/show_bug.cgi?id=1762827 and similar
if rpm -q ibm-semeru-open-11-jdk || rpm -q java-11-openj9-devel; then
    for pkg in java-11-openjdk-devel \
           java-11-openjdk-headless \
           java-11-openjdk; do
        if rpm -q "$pkg"; then
            rpm -e --nodeps "$pkg"
        fi
    done
fi
