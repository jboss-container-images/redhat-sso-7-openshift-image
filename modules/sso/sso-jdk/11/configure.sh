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
if [[ ($(uname -i) = ppc64le) || ($(uname -i) = s390x) ]]
then
  alternatives --set java /usr/lib/jvm/ibm-semeru-open-11-jdk/bin/java
  alternatives --set javac /usr/lib/jvm/ibm-semeru-open-11-jdk/bin/javac
  JAVA_SECURITY_FILE=/usr/lib/jvm/ibm-semeru-open-11-jdk/conf/security/java.security
  JAVA_HOME=/usr/lib/jvm/ibm-semeru-open-11-jdk/
else
  _arch="$(uname -i)"
  alternatives --set java java-11-openjdk.${_arch}
  alternatives --set javac java-11-openjdk.${_arch}
  alternatives --set java_sdk_openjdk java-11-openjdk.${_arch}
  alternatives --set jre_openjdk java-11-openjdk.${_arch}
  JAVA_SECURITY_FILE=/usr/lib/jvm/java/conf/security/java.security
  JAVA_HOME=/usr/lib/jvm/java-11/
fi

# Update securerandom.source for quicker starts (must be done after removing jdk 11, or it will hit the wrong files)
SECURERANDOM=securerandom.source
if grep -q "^$SECURERANDOM=.*" $JAVA_SECURITY_FILE; then
    sed -i "s|^$SECURERANDOM=.*|$SECURERANDOM=file:/dev/urandom|" $JAVA_SECURITY_FILE
else
    echo $SECURERANDOM=file:/dev/urandom >> $JAVA_SECURITY_FILE
fi
