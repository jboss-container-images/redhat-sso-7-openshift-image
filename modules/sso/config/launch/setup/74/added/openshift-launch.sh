#!/bin/sh
# Openshift EAP launch script

source ${JBOSS_HOME}/bin/launch/openshift-common.sh
source $JBOSS_HOME/bin/launch/logging.sh

STATISTICS_ARGS=""
if [ "${STATISTICS_ENABLED^^}" = "TRUE" ]; then
  STATISTICS_ARGS="-bmanagement 0.0.0.0 -Dwildfly.statistics-enabled=true"
fi


# TERM signal handler
function clean_shutdown() {
  log_error "*** JBossAS wrapper process ($$) received TERM signal ***"
  $JBOSS_HOME/bin/jboss-cli.sh -c ":shutdown(timeout=60)"
  wait $!
}

function runServer() {
  local instanceDir=$1
  local count=$2

  export NODE_NAME="${NODE_NAME:-node}-${count}"

  source $JBOSS_HOME/bin/launch/configure.sh

  log_info "Running $JBOSS_IMAGE_NAME image, version $JBOSS_IMAGE_VERSION"

  trap "clean_shutdown" TERM

  if [ -n "${SSO_HOSTNAME}" ]; then
    set_server_hostname_spi_to_fixed "${SSO_HOSTNAME}"
  fi

  if [ -n "$SSO_IMPORT_FILE" ] && [ -f $SSO_IMPORT_FILE ]; then
    $JBOSS_HOME/bin/standalone.sh -c standalone-openshift.xml $JBOSS_HA_ARGS $STATISTICS_ARGS -Djboss.server.data.dir="$instanceDir" ${JBOSS_MESSAGING_ARGS} -Dkeycloak.migration.action=import -Dkeycloak.migration.provider=singleFile -Dkeycloak.migration.file=${SSO_IMPORT_FILE} -Dkeycloak.migration.strategy=IGNORE_EXISTING ${JAVA_PROXY_OPTIONS}  &
  else
    $JBOSS_HOME/bin/standalone.sh -c standalone-openshift.xml $JBOSS_HA_ARGS $STATISTICS_ARGS -Djboss.server.data.dir="$instanceDir" ${JBOSS_MESSAGING_ARGS} ${JAVA_PROXY_OPTIONS} &
  fi

  PID=$!
  wait $PID 2>/dev/null
  wait $PID 2>/dev/null
}

function init_data_dir() {
  local DATA_DIR="$1"
  if [ -d "${JBOSS_HOME}/standalone/data" ]; then
    cp -rf ${JBOSS_HOME}/standalone/data/* $DATA_DIR
  fi
}

# Runtime /etc/passwd file permissions safety check to prevent reintroduction
# of CVE-2020-10695. !!! DO NOT REMOVE !!!
ETC_PASSWD_PERMS=$(stat -c '%a' "/etc/passwd")
if [ "${ETC_PASSWD_PERMS}" -gt "644" ]
then
  ERROR_MESSAGE=(
    "Permissions '${ETC_PASSWD_PERMS}' for '/etc/passwd' are too open!"
    "It is recommended the '/etc/passwd' file can only be modified by"
    "root or users with sudo privileges and readable by all system users."
    "Cannot start the '${JBOSS_IMAGE_NAME}', version '${JBOSS_IMAGE_VERSION}'!"
  )
  for msg in "${ERROR_MESSAGE[@]}"; do log_error "${msg}"; done
  exit 1
fi

if [ "${SPLIT_DATA^^}" = "TRUE" ]; then
  source /opt/partition/partitionPV.sh

  DATA_DIR="${JBOSS_HOME}/standalone/partitioned_data"

  partitionPV "${DATA_DIR}" "${SPLIT_LOCK_TIMEOUT:-30}"
else
  source $JBOSS_HOME/bin/launch/configure.sh

  log_info "Running $JBOSS_IMAGE_NAME image, version $JBOSS_IMAGE_VERSION"

  trap "clean_shutdown" TERM

  if [ -n "${SSO_HOSTNAME}" ]; then
    set_server_hostname_spi_to_fixed "${SSO_HOSTNAME}"
  fi

  if [ -n "$CLI_GRACEFUL_SHUTDOWN" ] ; then
    trap "" TERM
    log_info "Using CLI Graceful Shutdown instead of TERM signal"
  fi

  if [ -n "$SSO_IMPORT_FILE" ] && [ -f $SSO_IMPORT_FILE ]; then
    $JBOSS_HOME/bin/standalone.sh -c standalone-openshift.xml $STATISTICS_ARGS $JBOSS_HA_ARGS ${JBOSS_MESSAGING_ARGS} -Dkeycloak.migration.action=import -Dkeycloak.migration.provider=singleFile -Dkeycloak.migration.file=${SSO_IMPORT_FILE} -Dkeycloak.migration.strategy=IGNORE_EXISTING ${JAVA_PROXY_OPTIONS} &
  else
    $JBOSS_HOME/bin/standalone.sh -c standalone-openshift.xml $STATISTICS_ARGS $JBOSS_HA_ARGS ${JBOSS_MESSAGING_ARGS} ${JAVA_PROXY_OPTIONS} &
  fi

  PID=$!
  wait $PID 2>/dev/null
  wait $PID 2>/dev/null
fi
