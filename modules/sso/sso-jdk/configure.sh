#!/bin/sh
# Configure module
set -e

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
chmod ug+x ${ARTIFACTS_DIR}/opt/jboss/container/openjdk/jdk/*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd

# Set this JDK as the alternative in use
_arch="$(uname -i)"
_v=`[[ $(uname -i) = s390x ]] && echo openj9 || echo openjdk`
alternatives --set java java-1.8.0-${_v}.${_arch}
alternatives --set javac java-1.8.0-${_v}.${_arch}
alternatives --set java_sdk_${_v} java-1.8.0-${_v}.${_arch}
alternatives --set jre_${_v} java-1.8.0-${_v}.${_arch}

# Update securerandom.source for quicker starts (must be done after removing jdk 8, or it will hit the wrong files)
JAVA_SECURITY_FILE=/usr/lib/jvm/java/jre/lib/security/java.security
SECURERANDOM=securerandom.source
if grep -q "^$SECURERANDOM=.*" $JAVA_SECURITY_FILE; then
    sed -i "s|^$SECURERANDOM=.*|$SECURERANDOM=file:/dev/urandom|" $JAVA_SECURITY_FILE
else
    echo $SECURERANDOM=file:/dev/urandom >> $JAVA_SECURITY_FILE
fi
