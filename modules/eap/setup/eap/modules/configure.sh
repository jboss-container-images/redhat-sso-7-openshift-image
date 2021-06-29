#!/bin/bash
set -e

### Start of: 'jboss-eap-7-image/modules/eap-74-galleon/7.4.0' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd
### End of: 'jboss-eap-7-image/modules/eap-74-galleon/7.4.0' module

### Start of: 'jboss-eap-modules/jboss/container/eap/setup' module
# Configure module

# Create empty JBOSS_HOME and needed directories for other modules to install content.
mkdir -p $JBOSS_HOME/bin/launch
mkdir -p ${JBOSS_HOME}/standalone/deployments/
### End of: 'jboss-eap-modules/jboss/container/eap/setup' module

### Start of: 'jboss-eap-7-image/modules/eap-install-cleanup' module


# https://issues.jboss.org/browse/CLOUD-1260
# https://issues.jboss.org/browse/CLOUD-1431
function remove_scrapped_jars {
  for file in $(find $JBOSS_HOME -name \*.jar); do
    if ! jar -tf  $file &> /dev/null; then
      echo "Cleaning up '$file' jar..."
      rm -rf $file
    fi
  done

  # https://issues.jboss.org/browse/CLOUD-1430
  find $JBOSS_HOME/bundles/system/layers/base/.overlays -type d -empty -delete
}

function update_permissions {
  chown -R jboss:root $JBOSS_HOME
  chmod 0755 $JBOSS_HOME
  chmod -R g+rwX $JBOSS_HOME
}

function aggregate_patched_modules {
 local sys_pkgs="$JBOSS_MODULES_SYSTEM_PKGS"
  if [ -n "$sys_pkgs" ]; then
    export JBOSS_MODULES_SYSTEM_PKGS=""
  fi

  export JBOSS_PIDFILE=/tmp/jboss.pid
  cp -r $JBOSS_HOME/standalone /tmp/

  $JBOSS_HOME/bin/standalone.sh --admin-only -Djboss.server.base.dir=/tmp/standalone &

  start=$(date +%s)
  end=$((start + 120))
  until $JBOSS_HOME/bin/jboss-cli.sh --command="connect" || [ $(date +%s) -ge "$end" ]; do
    sleep 5
  done

  timeout 30 $JBOSS_HOME/bin/jboss-cli.sh --connect --command="/core-service=patching:ageout-history"
  timeout 30 $JBOSS_HOME/bin/jboss-cli.sh --connect --command="shutdown"

  # give it a moment to settle
  for i in $(seq 1 10); do
      test -e "$JBOSS_PIDFILE" || break
      sleep 1
  done

  # EAP still running? something is not right
  if test -e "$JBOSS_PIDFILE"; then
      echo "EAP instance still running; aborting" >&2
      exit 1
  fi

  rm -rf /tmp/standalone
}

# No patches for now
## aggregate_patched_modules
## remove_scrapped_jars
update_permissions

### End of: 'jboss-eap-7-image/modules/eap-install-cleanup' module

### Start of: 'cct_module/jboss/container/maven/module' module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

cp ${ARTIFACTS_DIR}/maven.module /etc/dnf/modules.d/maven.module
### End of: 'cct_module/jboss/container/maven/module' module

### Start of: 'cct_module/jboss/container/maven/8.2.3.6' module

# This file is shipped by a Maven package and sets JAVA_HOME to
# an OpenJDK-specific path. This causes problems for OpenJ9 containers
# as the path is not correct for them.  We don't need this in any of
# the containers because ew set JAVA_HOME in the container metadata.
# Blank the file rather than removing it, to avoid a warning message
# from /usr/bin/mvn.
if [ -f /etc/java/maven.conf ]; then
  :> /etc/java/maven.conf
fi
### End of: 'cct_module/jboss/container/maven/8.2.3.6' module

### Start of: 'cct_module/jboss/container/maven/module' module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

cp ${ARTIFACTS_DIR}/maven.module /etc/dnf/modules.d/maven.module
### End of: 'cct_module/jboss/container/maven/module' module

### Start of: 'jboss-eap-modules/os-eap-python/3.6' module

alternatives --set python /usr/bin/python3
### End of: 'jboss-eap-modules/os-eap-python/3.6' module

### Start of: 'cct_module/jboss/container/jolokia/8.2' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

# Start of RH-SSO add-on:
# -----------------------
# Replace the instances containing hardcoded '/opt/jboss/container/jolokia'
# (sub) paths with the value of 'JBOSS_CONTAINER_JOLOKIA_MODULE' variable
# instead
chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
# RH-SSO add-on:
# The asterisk '*' character in the following statement was intentionally left
# outside of the enclosing double-quotes to achieve proper Bash globbing prior
# the actual execution of the statement
chmod ug+x "${ARTIFACTS_DIR}/${JBOSS_CONTAINER_JOLOKIA_MODULE}/"*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd

mkdir -p "${JBOSS_CONTAINER_JOLOKIA_MODULE}/etc"
chmod 775 "${JBOSS_CONTAINER_JOLOKIA_MODULE}/etc"
chown -R jboss:root "${JBOSS_CONTAINER_JOLOKIA_MODULE}/etc"
# --------------------
# End of RH-SSO add-on
### End of: 'cct_module/jboss/container/jolokia/8.2' module

### Start of: 'cct_module/jboss/container/jolokia/8.2' module

# Legacy (pre-RPM) location
ln -s /usr/share/java/jolokia-jvm-agent/jolokia-jvm.jar \
      "${JBOSS_CONTAINER_JOLOKIA_MODULE}/jolokia.jar"
### End of: 'cct_module/jboss/container/jolokia/8.2' module

### Start of: 'cct_module/jboss/container/prometheus/8.2' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root ${ARTIFACTS_DIR}
chmod 755 ${ARTIFACTS_DIR}/opt/jboss/container/prometheus/prometheus-opts
chmod 775 ${ARTIFACTS_DIR}/opt/jboss/container/prometheus/etc
chmod 775 ${ARTIFACTS_DIR}/opt/jboss/container/prometheus/etc/jmx-exporter-config.yaml

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd
### End of: 'cct_module/jboss/container/prometheus/8.2' module

### Start of: 'cct_module/jboss/container/prometheus/8.2' module
set -ueo pipefail

# Legacy location
ln -s /usr/share/java/prometheus-jmx-exporter/jmx_prometheus_javaagent.jar \
	$JBOSS_CONTAINER_PROMETHEUS_MODULE/jmx_prometheus_javaagent.jar
### End of: 'cct_module/jboss/container/prometheus/8.2' module

### Start of: 'cct_module/jboss/container/java/proxy/bash' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
chmod ug+x ${ARTIFACTS_DIR}/opt/jboss/container/java/proxy*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd
### End of: 'cct_module/jboss/container/java/proxy/bash' module

### Start of: 'cct_module/jboss/container/java/proxy/bash' module
# Configure module

# For backward compatibility
mkdir -p /opt/run-java
ln -s /opt/jboss/container/java/proxy/* /opt/run-java

chown -R jboss:root /opt/run-java
### End of: 'cct_module/jboss/container/java/proxy/bash' module

### Start of: 'cct_module/jboss/container/java/jvm/bash' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
chmod ug+x ${ARTIFACTS_DIR}/opt/jboss/container/java/jvm/*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd
### End of: 'cct_module/jboss/container/java/jvm/bash' module

### Start of: 'cct_module/jboss/container/java/jvm/bash' module
# Configure module

# For backward compatibility
mkdir -p /opt/run-java
ln -s /opt/jboss/container/java/jvm/* /opt/run-java

chown -R jboss:root /opt/run-java
### End of: 'cct_module/jboss/container/java/jvm/bash' module

### Start of: 'cct_module/dynamic-resources' module

SCRIPT_DIR=$(dirname $0)

# Add jboss user to root group
usermod -g root -G jboss jboss

mkdir -p /usr/local/dynamic-resources
cp -p $SCRIPT_DIR/dynamic_resources.sh /usr/local/dynamic-resources/

chown -R jboss:root /usr/local/dynamic-resources/
chmod -R g+rwX /usr/local/dynamic-resources/
### End of: 'cct_module/dynamic-resources' module

### Start of: 'cct_module/jboss/container/s2i/core/bash' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
chmod ug+x ${ARTIFACTS_DIR}/opt/jboss/container/s2i/core/*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd

mkdir -p /usr/local/s2i \
 && chmod 775 /usr/local/s2i \
 && chown -R jboss:root /usr/local/s2i

mkdir -p /deployments \
 && chmod -R "ug+rwX" /deployments \
 && chown -R jboss:root /deployments
### End of: 'cct_module/jboss/container/s2i/core/bash' module

### Start of: 'cct_module/jboss/container/maven/default' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

# configure artifact permissions
chown -R jboss:root $ARTIFACTS_DIR
chmod -R ug+rwX $ARTIFACTS_DIR
chmod ug+x ${ARTIFACTS_DIR}/opt/jboss/container/maven/default/maven.sh

# install artifacts
pushd ${ARTIFACTS_DIR}
cp -pr * /
popd

MAVEN_VERSION_SQUASHED=${MAVEN_VERSION/./}

# pull in specific maven version to serve as default
for f in /opt/jboss/container/maven/${MAVEN_VERSION_SQUASHED}/*; do
    if test -f "$f"; then
        ln -s "$f" /opt/jboss/container/maven/default;
    fi;
done
chown -h jboss:root /opt/jboss/container/maven/default/*

# install default settings.xml file in user home
mkdir -p $HOME/.m2
ln -s /opt/jboss/container/maven/default/jboss-settings.xml $HOME/.m2/settings.xml

chown -R jboss:root $HOME/.m2
chmod -R ug+rwX $HOME/.m2
### End of: 'cct_module/jboss/container/maven/default' module

### Start of: 'cct_module/jboss/container/maven/default' module
# Configure module
# For backward compatibility
mkdir -p /usr/local/s2i
# scl-enable-maven is not needed on ubi8 images.
if test -r "${JBOSS_CONTAINER_MAVEN_DEFAULT_MODULE}/scl-enable-maven"; then
    ln -s /opt/jboss/container/maven/default/scl-enable-maven /usr/local/s2i/scl-enable-maven
    chown -h jboss:root /usr/local/s2i/scl-enable-maven
fi

ln -s /opt/jboss/container/maven/default/maven.sh /usr/local/s2i/common.sh
chown -h jboss:root /usr/local/s2i/common.sh
### End of: 'cct_module/jboss/container/maven/default' module

### Start of: 'cct_module/jboss/container/util/logging/bash' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
chmod ug+x ${ARTIFACTS_DIR}/opt/jboss/container/util/logging/*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd
### End of: 'cct_module/jboss/container/util/logging/bash' module

### Start of: 'cct_module/jboss/container/util/logging/bash' module

#if [ -n "$AMQ_HOME" ]; then
#  BIN_HOME="$AMQ_HOME"
#elif [ -n "$JWS_HOME" ]; then
#  BIN_HOME="$JWS_HOME"
#else
BIN_HOME="$JBOSS_HOME"
#fi

LAUNCH_DIR=${LAUNCH_DIR:-$BIN_HOME/bin/launch}

mkdir -pm 775 ${LAUNCH_DIR}
ln -s /opt/jboss/container/util/logging/logging.sh ${LAUNCH_DIR}/logging.sh

chown -R jboss:root ${LAUNCH_DIR}
chmod -R ug+rwX ${LAUNCH_DIR}

### End of: 'cct_module/jboss/container/util/logging/bash' module

### Start of: 'cct_module/jboss/container/maven/s2i' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
chmod ug+x ${ARTIFACTS_DIR}/opt/jboss/container/maven/s2i/*
chmod ug+x ${ARTIFACTS_DIR}/usr/local/s2i/*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd
### End of: 'cct_module/jboss/container/maven/s2i' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/s2i/bash' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
chmod ug+x ${ARTIFACTS_DIR}/opt/jboss/container/wildfly/s2i/*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd

# Construct the settings in use by galleon at provisioning and startup.
cp $HOME/.m2/settings.xml "$GALLEON_MAVEN_SETTINGS_XML"
local_repo_xml="\n\
  <localRepository>${GALLEON_LOCAL_MAVEN_REPO}</localRepository>"
sed -i "s|<!-- ### configured local repository ### -->|${local_repo_xml}|" "$GALLEON_MAVEN_SETTINGS_XML"
chown jboss:root $GALLEON_MAVEN_SETTINGS_XML
chmod ug+rwX $GALLEON_MAVEN_SETTINGS_XML

# Construct the settings used to build the image if not provided
if [ ! -f "$GALLEON_MAVEN_BUILD_IMG_SETTINGS_XML" ]; then
  cp $HOME/.m2/settings.xml "$GALLEON_MAVEN_BUILD_IMG_SETTINGS_XML"
  local_repo_xml="\n\
    <localRepository>${TMP_GALLEON_LOCAL_MAVEN_REPO}</localRepository>"
  sed -i "s|<!-- ### configured local repository ### -->|${local_repo_xml}|" "$GALLEON_MAVEN_BUILD_IMG_SETTINGS_XML"
  chown jboss:root $GALLEON_MAVEN_BUILD_IMG_SETTINGS_XML
  chmod ug+rwX $GALLEON_MAVEN_BUILD_IMG_SETTINGS_XML
fi

ln -s /opt/jboss/container/wildfly/s2i/install-common/install-common.sh /usr/local/s2i/install-common.sh
chown -h jboss:root /usr/local/s2i/install-common.sh

mkdir $WILDFLY_S2I_OUTPUT_DIR && chown -R jboss:root $WILDFLY_S2I_OUTPUT_DIR && chmod -R ug+rwX $WILDFLY_S2I_OUTPUT_DIR

# In order for applications to benefit from Galleon already downloaded artifacts
galleon_profile="<profile>\n\
      <id>local-galleon-repository</id>\n\
      <activation><activeByDefault>true</activeByDefault></activation>\n\
      <repositories>\n\
        <repository>\n\
          <id>local-galleon-repository</id>\n\
          <url>file://$GALLEON_LOCAL_MAVEN_REPO</url>\n\
          <releases>\n\
            <enabled>true</enabled>\n\
          </releases>\n\
          <snapshots>\n\
            <enabled>false</enabled>\n\
          </snapshots>\n\
        </repository>\n\
      </repositories>\n\
      <pluginRepositories>\n\
        <pluginRepository>\n\
          <id>local-galleon-plugin-repository</id>\n\
          <url>file://$GALLEON_LOCAL_MAVEN_REPO</url>\n\
          <releases>\n\
            <enabled>true</enabled>\n\
          </releases>\n\
          <snapshots>\n\
            <enabled>false</enabled>\n\
          </snapshots>\n\
        </pluginRepository>\n\
      </pluginRepositories>\n\
    </profile>\n\
"
sed -i "s|<\!-- ### configured profiles ### -->|$galleon_profile <\!-- ### configured profiles ### -->|" $HOME/.m2/settings.xml
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/s2i/bash' module

### Start of: 'jboss-eap-modules/jboss/container/eap/s2i/galleon' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
chmod ug+x ${ARTIFACTS_DIR}/usr/local/s2i/*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd
### End of: 'jboss-eap-modules/jboss/container/eap/s2i/galleon' module

### Start of: 'jboss-eap-modules/jboss/container/eap/s2i/galleon' module
# Set up Hawkular for java s2i builder image
mkdir -p /opt/jboss/container/eap/s2i/
ln -s /opt/jboss/container/wildfly/s2i/install-common/install-common.sh /opt/jboss/container/eap/s2i/install-common.sh

chown -h jboss:root /opt/jboss/container/eap/s2i/install-common.sh
### End of: 'jboss-eap-modules/jboss/container/eap/s2i/galleon' module

### Start of: 'jboss-eap-modules/jboss/container/eap/galleon' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd
### End of: 'jboss-eap-modules/jboss/container/eap/galleon' module

### Start of: 'jboss-eap-modules/jboss/container/eap/galleon/config/ee' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd
### End of: 'jboss-eap-modules/jboss/container/eap/galleon/config/ee' module

### Start of: 'jboss-eap-modules/jboss/container/eap/galleon/build-settings/osbs' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

cp ${ARTIFACTS_DIR}/settings.xml $GALLEON_MAVEN_BUILD_IMG_SETTINGS_XML
### End of: 'jboss-eap-modules/jboss/container/eap/galleon/build-settings/osbs' module

### Start of: 'jboss-eap-modules/jboss/container/eap/openshift/modules' module

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added
SOURCES_DIR="/tmp/artifacts"
VERSION_TXN_MARKER="1.1.4.Final-redhat-00001"

# Add new "openshift" layer
cp -rp --remove-destination "$ADDED_DIR/modules" "$JBOSS_HOME/"

cp -p "${SOURCES_DIR}/txn-recovery-marker-jdbc-common-${VERSION_TXN_MARKER}.jar" "$JBOSS_HOME/modules/system/layers/openshift/io/narayana/openshift-recovery/main/txn-recovery-marker-jdbc-common.jar"
cp -p "${SOURCES_DIR}/txn-recovery-marker-jdbc-hibernate5-${VERSION_TXN_MARKER}.jar" "$JBOSS_HOME/modules/system/layers/openshift/io/narayana/openshift-recovery/main/txn-recovery-marker-jdbc-hibernate5.jar"

chown -R jboss:root $JBOSS_HOME
chmod -R g+rwX $JBOSS_HOME
### End of: 'jboss-eap-modules/jboss/container/eap/openshift/modules' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/admin' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p ${JBOSS_HOME}/bin/launch/
cp -p ${ADDED_DIR}/launch/admin.sh ${JBOSS_HOME}/bin/launch/
cp -p ${ADDED_DIR}/launch/management-common.sh ${JBOSS_HOME}/bin/launch/
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/admin' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/access-log-valve' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p ${JBOSS_HOME}/bin/launch/
cp -p ${ADDED_DIR}/launch/* ${JBOSS_HOME}/bin/launch/
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/access-log-valve' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch-config/config' module
# Openshift

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

# Add custom startup scripts
mkdir -p ${JBOSS_HOME}/bin/launch
cp -r ${ADDED_DIR}/launch/* ${JBOSS_HOME}/bin/launch
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch-config/config' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch-config/os' module
# Openshift

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

# Add custom startup scripts
mkdir -p ${JBOSS_HOME}/bin/launch
cp -r ${ADDED_DIR}/launch/* ${JBOSS_HOME}/bin/launch
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch-config/os' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/os/node-name' module
set -u

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

# Add custom launch script and dependent scripts/libraries/snippets
mkdir -p ${JBOSS_HOME}/bin/launch
cp -r ${ADDED_DIR}/launch/* ${JBOSS_HOME}/bin/launch
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/os/node-name' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/datasources' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p ${JBOSS_HOME}/bin/launch
cp -r ${ADDED_DIR}/launch/* ${JBOSS_HOME}/bin/launch
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/datasources' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/extensions' module

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cp $ADDED_DIR/configure_extensions.sh $JBOSS_HOME/bin/launch

### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/extensions' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/json-logging' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p ${JBOSS_HOME}/standalone/configuration/
cp -p ${ADDED_DIR}/logging.properties ${JBOSS_HOME}/standalone/configuration/

mkdir -p ${JBOSS_HOME}/bin/launch/
cp -p ${ADDED_DIR}/launch/json_logging.sh ${JBOSS_HOME}/bin/launch/
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/json-logging' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/jgroups' module
# EAP JGroups configuration script and helpers

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p ${JBOSS_HOME}/bin/launch
cp -r ${ADDED_DIR}/launch/* ${JBOSS_HOME}/bin/launch
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/jgroups' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/deployment-scanner' module

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p ${JBOSS_HOME}/bin/launch
cp -r ${ADDED_DIR}/launch/deploymentScanner.sh ${JBOSS_HOME}/bin/launch

chown jboss:root $JBOSS_HOME/bin/launch/deploymentScanner.sh
chmod g+rwX $JBOSS_HOME/bin/launch/deploymentScanner.sh
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/deployment-scanner' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/keycloak' module

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p $JBOSS_HOME/bin/launch

cp ${ADDED_DIR}/keycloak.sh $JBOSS_HOME/bin/launch

cp ${ADDED_DIR}/keycloak-realm-subsystem $JBOSS_HOME/bin/launch/
cp ${ADDED_DIR}/keycloak-saml-realm-subsystem $JBOSS_HOME/bin/launch/
cp ${ADDED_DIR}/keycloak-deployment-subsystem $JBOSS_HOME/bin/launch/
cp ${ADDED_DIR}/keycloak-saml-deployment-subsystem $JBOSS_HOME/bin/launch/
cp ${ADDED_DIR}/keycloak-saml-sp-subsystem $JBOSS_HOME/bin/launch/
cp ${ADDED_DIR}/keycloak-security-domain $JBOSS_HOME/bin/launch/
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/keycloak' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/https' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p ${JBOSS_HOME}/bin/launch/
cp -p ${ADDED_DIR}/https.sh ${JBOSS_HOME}/bin/launch/
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/https' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/security-domains' module

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cp -p ${ADDED_DIR}/launch/security-domains.sh ${JBOSS_HOME}/bin/launch/
chmod ug+x ${JBOSS_HOME}/bin/launch/security-domains.sh
cp -p ${ADDED_DIR}/launch/login-modules-common.sh ${JBOSS_HOME}/bin/launch/
chmod ug+x ${JBOSS_HOME}/bin/launch/login-modules-common.sh


### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/security-domains' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/elytron' module

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added
SOURCES_DIR="/tmp/artifacts"

cp -p ${ADDED_DIR}/launch/elytron.sh ${JBOSS_HOME}/bin/launch/
chmod ug+x ${JBOSS_HOME}/bin/launch/elytron.sh


### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/elytron' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/port-offset' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p ${JBOSS_HOME}/bin/launch/
cp -p ${ADDED_DIR}/launch/ports.sh ${JBOSS_HOME}/bin/launch/
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/port-offset' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/resource-adapters' module

CRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

mkdir -p ${JBOSS_HOME}/bin/launch
cp -r ${ADDED_DIR}/launch/* ${JBOSS_HOME}/bin/launch
### Endf of: 'wildfly-cekit-modules/jboss/container/wildfly/launch/resource-adapters' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/galleon/fp-content/jolokia' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cp -r ${ADDED_DIR}/* ${GALLEON_FP_PATH}
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/galleon/fp-content/jolokia' module

### Start of RH-SSO add-on: Install 'keycloak-server-overlay.zip' artifact

ARTIFACTS_DIR="/tmp/artifacts"

unzip -o "${ARTIFACTS_DIR}/keycloak-server-overlay.zip" -d "${JBOSS_HOME}"

chown -R jboss:root "${JBOSS_HOME}"
chmod -R g+rwX "${JBOSS_HOME}"

### Endf of RH-SSO add-on: Install 'keycloak-server-overlay.zip' artifact

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/galleon/fp-content/java' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cp -r ${ADDED_DIR}/* ${GALLEON_FP_PATH}
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/galleon/fp-content/java' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/galleon/fp-content/config' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cp -r ${ADDED_DIR}/* ${GALLEON_FP_PATH}
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/galleon/fp-content/config' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/galleon/fp-content/mvn' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cp -r ${ADDED_DIR}/* ${GALLEON_FP_PATH}
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/galleon/fp-content/mvn' module

### Start of: 'wildfly-cekit-modules/jboss/container/wildfly/galleon/fp-content/ejb-tx-recovery' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cp -r ${ADDED_DIR}/* ${GALLEON_FP_PATH}
### End of: 'wildfly-cekit-modules/jboss/container/wildfly/galleon/fp-content/ejb-tx-recovery' module

### Start of: 'jboss-eap-modules/os-eap-probes/common' module

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

# Add liveness and readiness probes and helper library
cp -r "$ADDED_DIR"/* $JBOSS_HOME/bin/

chown -R jboss:root $JBOSS_HOME/bin/
chmod -R g+rwX $JBOSS_HOME/bin/

# ensure added scripts are executable
chmod ug+x $JBOSS_HOME/bin/readinessProbe.sh $JBOSS_HOME/bin/livenessProbe.sh
chmod -R ug+x $JBOSS_HOME/bin/probes
### End of: 'jboss-eap-modules/os-eap-probes/common' module

### Start of: 'jboss-eap-modules/os-eap-probes/3.0' module

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

# Add jolokia specific scripts
cp -r "$ADDED_DIR"/* $JBOSS_HOME/bin/

chown -R jboss:root $JBOSS_HOME/bin/
chmod -R g+rwX $JBOSS_HOME/bin/
### End of: 'jboss-eap-modules/os-eap-probes/3.0' module

### Start of: 'jboss-eap-modules/jboss/container/eap/hawkular' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cp -r ${ADDED_DIR}/* ${GALLEON_FP_PATH}
### End of: 'jboss-eap-modules/jboss/container/eap/hawkular' module

### Start of: 'jboss-eap-modules/jboss/container/eap/prometheus/jmx-exporter-config' module
# Configure module

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root ${ARTIFACTS_DIR}
chmod 775 ${ARTIFACTS_DIR}/opt/jboss/container/prometheus/etc/jmx-exporter-config.yaml

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd
### End of: 'jboss-eap-modules/jboss/container/eap/prometheus/jmx-exporter-config' module

### Start of: 'jboss-eap-modules/jboss/container/eap/prometheus/config' module


SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added

cp -r ${ADDED_DIR}/* ${GALLEON_FP_PATH}
### End of: 'jboss-eap-modules/jboss/container/eap/prometheus/config' module

### Start of: 'jboss.container.wildfly.galleon.build-feature-pack' module
# Configure module

if [ -z "$WILDFLY_VERSION" ]; then
  echo "WILDFLY_VERSION must be set"
  exit 1
fi

if [ -z "$WILDFLY_DIST_MAVEN_LOCATION" ]; then
  echo "WILDFLY_DIST_MAVEN_LOCATION must be set to the URL to WildFly dist maven artifact"
  exit 1
fi

if [ -z "$OFFLINER_URLS" ]; then
  echo "OFFLINER_URLS must be set, format \"--url <maven repo url> [--url <maven repo url>]"
  exit 1
fi

if [ -z "$GALLEON_FP_PATH" ]; then
  echo "GALLEON_FP_PATH must be set to the galleon feature-pack maven project location"
  exit 1
fi

deleteBuildArtifacts=${DELETE_BUILD_ARTIFACTS:-false}

ZIPPED_REPO="/tmp/artifacts/maven-repo.zip"
if [ -f "${ZIPPED_REPO}" ]; then
  echo "Found zipped repository, installing it."
  unzip ${ZIPPED_REPO} -d /tmp
  repoDir=$(find /tmp -type d -iname "*-image-builder-maven-repository")

  # hook to allow for maven-repo processing before to initiate feature-pack build
  if [ -f "$GALLEON_MAVEN_REPO_HOOK_SCRIPT" ]; then
    sh $GALLEON_MAVEN_REPO_HOOK_SCRIPT "$repoDir"
  fi
  mv $repoDir/maven-repository "$TMP_GALLEON_LOCAL_MAVEN_REPO"
  mkdir "$JBOSS_CONTAINER_WILDFLY_S2I_GALLEON_DIR/maven-repo-misc"
  if [ "$(ls -A $repoDir)" ]; then
    mv $repoDir/* "$JBOSS_CONTAINER_WILDFLY_S2I_GALLEON_DIR/maven-repo-misc"
  fi
  rm -rf $repoDir
  if [ "x$deleteBuildArtifacts" == "xtrue"  ]; then
    echo "Build artifacts are not kept, will be removed from galleon local cache"
    cp -r $TMP_GALLEON_LOCAL_MAVEN_REPO $GALLEON_LOCAL_MAVEN_REPO
  fi
else
  # Download offliner runtime
  curl -o /tmp/offliner.jar -v -L https://repo.maven.apache.org/maven2/com/redhat/red/offliner/offliner/$OFFLINER_VERSION/offliner-$OFFLINER_VERSION.jar

  # Download offliner file
  curl -o /tmp/offliner.txt -v -L $WILDFLY_DIST_MAVEN_LOCATION/$WILDFLY_VERSION/wildfly-dist-$WILDFLY_VERSION-artifact-list.txt

  # Populate maven repo, in case we have errors (occur when using locally built WildFly, no md5 nor sha files), cd to /tmp where error.logs is written.
  cd /tmp
  java -jar /tmp/offliner.jar $OFFLINER_URLS \
  /tmp/offliner.txt --dir $TMP_GALLEON_LOCAL_MAVEN_REPO > /dev/null
  if [ -f ./errors.log ]; then
    echo ERRORS WHILE RETRIEVING ARTIFACTS.
    echo Offliner errors:
    cat ./errors.log
    exit 1
  fi
  cd ..

  rm /tmp/offliner.jar && rm /tmp/offliner.txt
fi

# these are sourced so the most recent version is last an will apply if present
if [ -f $JBOSS_CONTAINER_MAVEN_35_MODULE/scl-enable-maven ]; then
  # required to have maven enabled.
  source $JBOSS_CONTAINER_MAVEN_35_MODULE/scl-enable-maven
fi

if [ -f $JBOSS_CONTAINER_MAVEN_36_MODULE/scl-enable-maven ]; then
  source $JBOSS_CONTAINER_MAVEN_36_MODULE/scl-enable-maven
fi

if [ -d "$JBOSS_HOME/modules" ]; then
  # Copy JBOSS_HOME/modules content (custom os modules) to modules.
  MODULES_DIR=$GALLEON_FP_PATH/src/main/resources/modules/
  mkdir -p $MODULES_DIR
  cp -r $JBOSS_HOME/modules/* $MODULES_DIR
  rm -rf $JBOSS_HOME/modules/
fi

# Install the producers and universe
mvn -f "$JBOSS_CONTAINER_WILDFLY_S2I_MODULE"/galleon/provisioning/jboss-s2i-producers/pom.xml install -Dmaven.repo.local=$TMP_GALLEON_LOCAL_MAVEN_REPO \
--settings $GALLEON_MAVEN_BUILD_IMG_SETTINGS_XML
mvn -f "$JBOSS_CONTAINER_WILDFLY_S2I_MODULE"/galleon/provisioning/jboss-s2i-universe/pom.xml install -Dmaven.repo.local=$TMP_GALLEON_LOCAL_MAVEN_REPO \
--settings $GALLEON_MAVEN_BUILD_IMG_SETTINGS_XML

# delete universe/producer src
rm -rf "$JBOSS_CONTAINER_WILDFLY_S2I_MODULE"/galleon/provisioning/jboss-s2i-universe
rm -rf "$JBOSS_CONTAINER_WILDFLY_S2I_MODULE"/galleon/provisioning/jboss-s2i-producers

if [ ! -z "$GALLEON_FP_COMMON_PKG_NAME" ]; then
  # Copy JBOSS_HOME content (custom os content) to common package dir
  CONTENT_DIR=$GALLEON_FP_PATH/src/main/resources/packages/$GALLEON_FP_COMMON_PKG_NAME/content
  mkdir -p $CONTENT_DIR
  cp -r $JBOSS_HOME/* $CONTENT_DIR
fi
rm -rf $JBOSS_HOME/*

# Start of RH-SSO add-on:
# -----------------------
# Ensure 'wildfly-galleon-maven-plugin-5.2.0.Alpha2.jar', 'wildfly-galleon-maven-plugin-5.2.0.Alpha2.pom', and
# 'wildfly-provisioning-parent-5.2.0.Alpha2.pom' artifacts are installed to expected location prior launching
# the following mvn command
#
declare -ar EXPECTED_WILDFLY_ARTIFACTS=(
  "wildfly-galleon-maven-plugin-5.2.0.Alpha2.jar"
  "wildfly-galleon-maven-plugin-5.2.0.Alpha2.pom"
  "wildfly-provisioning-parent-5.2.0.Alpha2.pom"
)
# Sanity check - confirm the required artifacts are present under "/tmp/artifacts" location
for artifact in "${EXPECTED_WILDFLY_ARTIFACTS[@]}"
do
  if [ ! -f "/tmp/artifacts/${artifact}" ]
  then
    echo "Missing '${artifact}' at /tmp/artifacts location. Please define it, and rerun the script."
    exit 1
  fi
done

# Copy the expected Wildfly artifacts (required by the following call to mvn) from /tmp/artifacts
# to their respective locations, they are expected at by the mvn tool

# Deal with 'wildfly-galleon-maven-plugin' artifacts
mkdir -p "${TMP_GALLEON_LOCAL_MAVEN_REPO}/org/wildfly/galleon-plugins/wildfly-galleon-maven-plugin/5.2.0.Alpha2"
cp "/tmp/artifacts/wildfly-galleon-maven-plugin-5.2.0.Alpha2.jar" \
   "/tmp/artifacts/wildfly-galleon-maven-plugin-5.2.0.Alpha2.pom" \
   "${TMP_GALLEON_LOCAL_MAVEN_REPO}/org/wildfly/galleon-plugins/wildfly-galleon-maven-plugin/5.2.0.Alpha2"

# Deal with 'wildfly-provisioning-parent' artifact
mkdir -p "${TMP_GALLEON_LOCAL_MAVEN_REPO}/org/wildfly/galleon-plugins/wildfly-provisioning-parent/5.2.0.Alpha2"
cp "/tmp/artifacts/wildfly-provisioning-parent-5.2.0.Alpha2.pom" \
   "${TMP_GALLEON_LOCAL_MAVEN_REPO}/org/wildfly/galleon-plugins/wildfly-provisioning-parent/5.2.0.Alpha2"

# --------------------
# End of RH-SSO add-on

# Build Galleon s2i feature-pack and install it in local maven repository
mvn -f $GALLEON_FP_PATH/pom.xml install \
--settings $GALLEON_MAVEN_BUILD_IMG_SETTINGS_XML -Dmaven.repo.local=$TMP_GALLEON_LOCAL_MAVEN_REPO $GALLEON_BUILD_FP_MAVEN_ARGS_APPEND

if [ "x$deleteBuildArtifacts" == "xtrue"  ]; then
  echo "Copying generated artifacts to galleon local cache"
  # Copy generated artifacts only
  mkdir -p $GALLEON_LOCAL_MAVEN_REPO/org/jboss/universe/
  cp -r $TMP_GALLEON_LOCAL_MAVEN_REPO/org/jboss/universe/s2i-universe $GALLEON_LOCAL_MAVEN_REPO/org/jboss/universe/
  mkdir -p $GALLEON_LOCAL_MAVEN_REPO/org/jboss/universe/producer
  cp -r $TMP_GALLEON_LOCAL_MAVEN_REPO/org/jboss/universe/producer/s2i-producers $GALLEON_LOCAL_MAVEN_REPO/org/jboss/universe/producer
  groupIdPath=${GALLEON_S2I_FP_GROUP_ID//./\/}
  mkdir -p $GALLEON_LOCAL_MAVEN_REPO/$groupIdPath
  cp -r $TMP_GALLEON_LOCAL_MAVEN_REPO/$groupIdPath/$GALLEON_S2I_FP_ARTIFACT_ID $GALLEON_LOCAL_MAVEN_REPO/$groupIdPath
fi

keepFP=${DEBUG_GALLEON_FP_SRC:-false}
if [ "x$keepFP" == "xfalse" ]; then
 echo Removing feature-pack src.
 # Remove the feature-pack src
 rm -rf $GALLEON_FP_PATH
fi
### End of: 'jboss.container.wildfly.galleon.build-feature-pack' module

### Start of: 'jboss.container.wildfly.galleon.provision-server' module
# Configure module

if [ ! -d "$GALLEON_DEFAULT_SERVER" ]; then
  echo "GALLEON_DEFAULT_SERVER must be set to the absolute path to directory that contains galleon default server provisioning file."
  exit 1
fi

# these are sourced so the most recent version is last and will be applied
if [ -f $JBOSS_CONTAINER_MAVEN_35_MODULE/scl-enable-maven ]; then
  # required to have maven enabled.
  source $JBOSS_CONTAINER_MAVEN_35_MODULE/scl-enable-maven
fi

if [ -f $JBOSS_CONTAINER_MAVEN_36_MODULE/scl-enable-maven ]; then
  source $JBOSS_CONTAINER_MAVEN_36_MODULE/scl-enable-maven
fi

# Start of RH-SSO add-on:
# -----------------------
# Set GALLEON_DEFAULT_SERVER_PROVISION_MAVEN_ARGS_APPEND environment variable
# to empty (zero-length) string if undefined to prevent unbound variable error
GALLEON_DEFAULT_SERVER_PROVISION_MAVEN_ARGS_APPEND="${GALLEON_DEFAULT_SERVER_PROVISION_MAVEN_ARGS_APPEND:-}"
# --------------------
# End of RH-SSO add-on

# Provision the default server
# The active profiles are jboss-community-repository and securecentral
cp "$GALLEON_DEFAULT_SERVER"/provisioning.xml "$JBOSS_CONTAINER_WILDFLY_S2I_GALLEON_PROVISION"

mvn -f "$JBOSS_CONTAINER_WILDFLY_S2I_GALLEON_PROVISION"/pom.xml package -Dmaven.repo.local=$TMP_GALLEON_LOCAL_MAVEN_REPO \
--settings $GALLEON_MAVEN_BUILD_IMG_SETTINGS_XML $GALLEON_DEFAULT_SERVER_PROVISION_MAVEN_ARGS_APPEND

TARGET_DIR="$JBOSS_CONTAINER_WILDFLY_S2I_GALLEON_PROVISION"/target
SERVER_DIR=$TARGET_DIR/server

if [ ! -d "$GALLEON_LOCAL_MAVEN_REPO" ]; then
  cp -r $TMP_GALLEON_LOCAL_MAVEN_REPO $GALLEON_LOCAL_MAVEN_REPO
fi

rm -rf $TMP_GALLEON_LOCAL_MAVEN_REPO

if [ ! -d $SERVER_DIR ]; then
  echo "Error, no server provisioned in $SERVER_DIR"
  exit 1
fi
# Install WildFly server
rm -rf $JBOSS_HOME
cp -r $SERVER_DIR $JBOSS_HOME
rm -r $TARGET_DIR

chown -R jboss:root $JBOSS_HOME && chmod -R ug+rwX $JBOSS_HOME

# Remove java tmp perf data dir owned by 185
rm -rf /tmp/hsperfdata_jboss
### End of: 'jboss.container.wildfly.galleon.provision-server' module

### Start of: 'jboss.container.eap.final-setup' module

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added
DEPLOYMENTS_DIR=/deployments

# https://issues.jboss.org/browse/CLOUD-128
if [ ! -d "${DEPLOYMENTS_DIR}" ]; then
  mv $JBOSS_HOME/standalone/deployments $DEPLOYMENTS_DIR
else
  # -T to avoid cping the deployments directory into the existing one
  cp -R -T $JBOSS_HOME/standalone/deployments/ ${DEPLOYMENTS_DIR}
  rm -rf $JBOSS_HOME/standalone/deployments
fi

ln -s /deployments $JBOSS_HOME/standalone/deployments
chown jboss:root $JBOSS_HOME/standalone/deployments

# Necessary to permit running with a randomised UID
for dir in ${JBOSS_HOME} $DEPLOYMENTS_DIR; do
    chown -R jboss:root $dir
    chmod -R g+rwX $dir
done
### End of: 'jboss.container.eap.final-setup' module
