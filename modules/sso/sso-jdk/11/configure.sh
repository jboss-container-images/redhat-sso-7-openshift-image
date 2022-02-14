#!/bin/sh
# Configure module
set -e

# Import RH-SSO global variables & functions to image build-time
# shellcheck disable=SC1091
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
chmod ug+x ${ARTIFACTS_DIR}/opt/jboss/container/openjdk/jdk/*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd

_arch="$(uname -i)"
alternatives --set java java-11-openjdk.${_arch}
alternatives --set javac java-11-openjdk.${_arch}
alternatives --set java_sdk_openjdk java-11-openjdk.${_arch}
alternatives --set jre_openjdk java-11-openjdk.${_arch}

# Update securerandom.source for quicker starts (must be done after removing jdk 8, or it will hit the wrong files)
JAVA_SECURITY_FILE=/usr/lib/jvm/java/conf/security/java.security
JAVA_HOME=/usr/lib/jvm/java-11/
# Update securerandom.source for quicker starts (must be done after removing jdk 11, or it will hit the wrong files)
SECURERANDOM=securerandom.source
if grep -q "^$SECURERANDOM=.*" $JAVA_SECURITY_FILE; then
    # CIAM-1394 correction
    sed -i "s${AUS}^$SECURERANDOM=.*${AUS}$SECURERANDOM=file:/dev/urandom${AUS}" $JAVA_SECURITY_FILE
    # EOF CIAM-1394 correction
else
    echo $SECURERANDOM=file:/dev/urandom >> $JAVA_SECURITY_FILE
fi

# CIAM-1757: On each arch remove JDK 1.8 rpms if present (since using JDK 11 already)
rpm --query --all name=java* version=1.8.0* | xargs rpm -e --nodeps
