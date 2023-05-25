#!/bin/bash
# Openshift RH-SSO launch script

# Import the necessary Bash modules
# shellcheck disable=SC1091
source "${JBOSS_HOME}"/bin/launch/sso-openshift-common.sh
# shellcheck disable=SC1091
source "${JBOSS_HOME}"/bin/launch/logging.sh

STATISTICS_ARGS=""
if [ "${STATISTICS_ENABLED^^}" = "TRUE" ]; then
  STATISTICS_ARGS="-bmanagement 0.0.0.0 -Dwildfly.statistics-enabled=true"
fi


# TERM signal handler
function clean_shutdown() {
  log_error "*** JBossAS wrapper process ($$) received TERM signal ***"
  "${JBOSS_HOME}"/bin/jboss-cli.sh -c ":shutdown(timeout=60)"
  wait $!
}

# RHSSO-1883
#
# In case the DB_SERVICE_PREFIX_MAPPING env var is set, for each of the
# defined DB backends verify they are ready to accept connections.
# In case if not, wait for them to become ready
#
function verify_db_backends_ready_to_accept_connections() {
  if [ -n "${DB_SERVICE_PREFIX_MAPPING}" ]; then
    # Delay (in seconds) how long to wait prior
    # performing next DB TCP connection readiness check
    # Default is 10 seconds
    local -r DEFAULT_FREQ="10"
    local -r CHECK_FREQ="${DB_READINESS_RETRY_WAIT_SECONDS:-${DEFAULT_FREQ}}"
    IFS=',' read -ra db_backends <<< "${DB_SERVICE_PREFIX_MAPPING}"
    for db_backend in "${db_backends[@]}"; do
      service_name=${db_backend%=*}
      service=${service_name^^}
      service=${service//-/_}
      db=${service##*_}
      # Kubernetes automatically creates environment variables, containing the service
      # host and port for all services that were running when a container was created:
      # * https://kubernetes.io/docs/concepts/containers/container-environment/#cluster-information
      # So if there exists a Kubernetes service for the DB backend, the pod environment
      # must contain an environment variable, value of which includes:
      # 1) Either "$service" substring, derived from DB_SERVICE_PREFIX_MAPPING env var
      # 2) Or "$db_SERVICE" substring, where $db is derived from the "$service" string above
      # Thus check the RH-SSO pod env for both substrings in that order
      #
      # Note: If following 'compgen' commands return more than just one variable, we intentionally want
      # the array to contain one element per variable, thus the corresponding ShellCheck test is disabled
      # shellcheck disable=SC2207
      declare -ra K8S_DB_SERVICE_HOST_VAR_NAME=(
        $(
          compgen -v | grep -sx "${service}_SERVICE_HOST" ||
          compgen -v | grep -sx "${db}_SERVICE_HOST"
        )
      )
      # Note: If following 'compgen' commands return more than just one variable, we intentionally want
      # the array to contain one element per variable, thus the corresponding ShellCheck test is disabled
      # shellcheck disable=SC2207
      declare -ra K8S_DB_SERVICE_PORT_VAR_NAME=(
        $(
          compgen -v | grep -sx "${service}_SERVICE_PORT" ||
          compgen -v | grep -sx "${db}_SERVICE_PORT"
        )
      )
      # If host/port is still unknown at this moment or there's more than one host/port entry, that's an error
      if [ "${#K8S_DB_SERVICE_HOST_VAR_NAME[@]}" -ne "1" ] || [ "${#K8S_DB_SERVICE_PORT_VAR_NAME[@]}" -ne "1" ]
      then
        log_error "Failed to determine the host and port of the database service to check."
        exit 1
      fi
      # Otherwise evaluate the actual values of both the DB service host and port
      # from the indirect references of automatic Kubernetes environment variables
      # created for the service
      local -r DB_HOST="${!K8S_DB_SERVICE_HOST_VAR_NAME[0]}"
      local -r DB_PORT="${!K8S_DB_SERVICE_PORT_VAR_NAME[0]}"
      # Finally wait for the DB system to become ready (wait till a moment, when
      # attempt to open a TCP connection to the remote DB backend actually succeeds)
      log_info "Checking connection readiness of the ${db} database system."
      log_info "To change the frequency of the check, set the DB_READINESS_RETRY_WAIT_SECONDS environment variable to a desired count of seconds (default is ${DEFAULT_FREQ}s)."
      until timeout 2 bash -c "</dev/tcp/${DB_HOST}/${DB_PORT}" >& /dev/null; do
        log_info "Waiting ${CHECK_FREQ} seconds for the ${db} database system to be ready to accept connections.."
        sleep "${CHECK_FREQ}"
      done
    done
  fi
}

function runServer() {
  local instanceDir=$1
  local count=$2

  export NODE_NAME="${NODE_NAME:-node}-${count}"

  source "${JBOSS_HOME}"/bin/launch/configure-modules.sh

  # RHSSO-1953 correction
  # The scripts will add the CLI operations in a special file,
  # invoke the embedded server if necessary and execute the CLI scripts.
  exec_cli_scripts "${CLI_SCRIPT_FILE}"
  # Ensure we start with clean CLI files since they were already executed
  createConfigExecutionContext
  # CIAM-1522 correction
  # if a delayedpostconfigure.sh file exists call it, otherwise fallback on postconfigure.sh
  executeModules delayedPostConfigure
  # EOF CIAM-1522 correction
  # Process any errors and warnings generated while running the launch configuration scripts
  if ! processErrorsAndWarnings; then
    exit 1
  fi
  # Re-run CLI scipts just in case a delayed postinstall updated
  # (added some new changes to) them
  exec_cli_scripts "${CLI_SCRIPT_FILE}"
  # EOF RHSSO-1953 correction

  verify_db_backends_ready_to_accept_connections
  log_info "Running $JBOSS_IMAGE_NAME image, version $JBOSS_IMAGE_VERSION"

  trap "clean_shutdown" TERM

  if [ -n "${SSO_HOSTNAME}" ]; then
    set_server_hostname_spi_to_fixed "${SSO_HOSTNAME}"
  fi

  # Note:
  # We intentionally want the JBOSS_HA_ARGS, STATISTICS_ARGS, JBOSS_MESSAGING_ARGS, and JAVA_PROXY_OPTIONS
  # environment variables in the next statement to be split at spaces as multiple CLI arguments passed to
  # the standalone.sh call, therefore the particular ShellCheck test is disabled
  # shellcheck disable=SC2086
  if [ -n "${SSO_IMPORT_FILE}" ] && [ -f "${SSO_IMPORT_FILE}" ]; then
    "${JBOSS_HOME}"/bin/standalone.sh -c standalone-openshift.xml $JBOSS_HA_ARGS $STATISTICS_ARGS -Djboss.server.data.dir="$instanceDir" ${JBOSS_MESSAGING_ARGS} -Dkeycloak.migration.action=import -Dkeycloak.migration.provider=singleFile -Dkeycloak.migration.file="${SSO_IMPORT_FILE}" -Dkeycloak.migration.strategy=IGNORE_EXISTING ${JAVA_PROXY_OPTIONS}  &
  else
    "${JBOSS_HOME}"/bin/standalone.sh -c standalone-openshift.xml $JBOSS_HA_ARGS $STATISTICS_ARGS -Djboss.server.data.dir="$instanceDir" ${JBOSS_MESSAGING_ARGS} ${JAVA_PROXY_OPTIONS} &
  fi

  PID=$!
  wait $PID 2>/dev/null
  wait $PID 2>/dev/null
}

function init_data_dir() {
  local DATA_DIR="$1"
  if [ -d "${JBOSS_HOME}"/standalone/data ]; then
    cp -rf "${JBOSS_HOME}"/standalone/data/* "${DATA_DIR}"
  fi
}

if [ "${SPLIT_DATA^^}" = "TRUE" ]; then
  source /opt/partition/partitionPV.sh

  DATA_DIR="${JBOSS_HOME}/standalone/partitioned_data"

  partitionPV "${DATA_DIR}" "${SPLIT_LOCK_TIMEOUT:-30}"
else
  source "${JBOSS_HOME}"/bin/launch/configure-modules.sh

  # RHSSO-1953 correction
  # The scripts will add the CLI operations in a special file,
  # invoke the embedded server if necessary and execute the CLI scripts.
  exec_cli_scripts "${CLI_SCRIPT_FILE}"
  # Ensure we start with clean CLI files since they were already executed
  createConfigExecutionContext
  # CIAM-1522 correction
  # if a delayedpostconfigure.sh file exists call it, otherwise fallback on postconfigure.sh
  executeModules delayedPostConfigure
  # EOF CIAM-1522 correction
  # Process any errors and warnings generated while running the launch configuration scripts
  if ! processErrorsAndWarnings; then
    exit 1
  fi
  # Re-run CLI scipts just in case a delayed postinstall updated
  # (added some new changes to) them
  exec_cli_scripts "${CLI_SCRIPT_FILE}"
  # EOF RHSSO-1953 correction

  verify_db_backends_ready_to_accept_connections
  log_info "Running $JBOSS_IMAGE_NAME image, version $JBOSS_IMAGE_VERSION"

  trap "clean_shutdown" TERM

  if [ -n "${SSO_HOSTNAME}" ]; then
    set_server_hostname_spi_to_fixed "${SSO_HOSTNAME}"
  fi

  if [ -n "$CLI_GRACEFUL_SHUTDOWN" ] ; then
    trap "" TERM
    log_info "Using CLI Graceful Shutdown instead of TERM signal"
  fi

  # Note:
  # We intentionally want the JBOSS_HA_ARGS, STATISTICS_ARGS, JBOSS_MESSAGING_ARGS, and JAVA_PROXY_OPTIONS
  # environment variables in the next statement to be split at spaces as multiple CLI arguments passed to
  # the standalone.sh call, therefore the particular ShellCheck test is disabled
  # shellcheck disable=SC2086
  if [ -n "${SSO_IMPORT_FILE}" ] && [ -f "${SSO_IMPORT_FILE}" ]; then
    "${JBOSS_HOME}"/bin/standalone.sh -c standalone-openshift.xml $STATISTICS_ARGS $JBOSS_HA_ARGS ${JBOSS_MESSAGING_ARGS} -Dkeycloak.migration.action=import -Dkeycloak.migration.provider=singleFile -Dkeycloak.migration.file="${SSO_IMPORT_FILE}" -Dkeycloak.migration.strategy=IGNORE_EXISTING ${JAVA_PROXY_OPTIONS} &
  else
    "${JBOSS_HOME}"/bin/standalone.sh -c standalone-openshift.xml $STATISTICS_ARGS $JBOSS_HA_ARGS ${JBOSS_MESSAGING_ARGS} ${JAVA_PROXY_OPTIONS} &
  fi

  PID=$!
  wait $PID 2>/dev/null
  wait $PID 2>/dev/null
fi
