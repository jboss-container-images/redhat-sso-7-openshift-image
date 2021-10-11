#!/bin/sh

source $JBOSS_HOME/bin/launch/datasource-common.sh

function preConfigure() {
  # Since inject_datasources_common ends up executing in a sub-shell for where I want
  # to grab the value, use temp files to store what was used
  initTempFiles

  # Remove the files if they exist
  if [ -s "${DEFAULT_JOB_REPOSITORY_FILE}" ]; then
    rm "${DEFAULT_JOB_REPOSITORY_FILE}"
  fi
  if [ -s "${TIMER_SERVICE_DATA_STORE_FILE}" ]; then
    rm "${TIMER_SERVICE_DATA_STORE_FILE}"
  fi
  if [ -s "${EE_DEFAULT_DATASOURCE_FILE}" ]; then
    rm "${EE_DEFAULT_DATASOURCE_FILE}"
  fi
}

function prepareEnv() {
  initTempFiles
  clearDatasourcesEnv
  clearTxDatasourceEnv
}

function configure() {
  initTempFiles
  inject_datasources
}

function configureEnv() {
  initTempFiles
  inject_external_datasources

  # TODO - I don't think this is being used any more? The real action seems to be in tx-datasource.sh
  if [ -n "$JDBC_STORE_JNDI_NAME" ]; then
    local jdbcStore="<jdbc-store datasource-jndi-name=\"${JDBC_STORE_JNDI_NAME}\"/>"
    sed -i "s|<!-- ##JDBC_STORE## -->|${jdbcStore}|" $CONFIG_FILE
  fi

}

function finalVerification() {
  initTempFiles
  if [ -n "${DEFAULT_JOB_REPOSITORY}" ] && [ ! -f "${DEFAULT_JOB_REPOSITORY_FILE}" ]; then
    echo "The list of configured datasources does not contain a datasource matching the default job repository datasource specified with DEFAULT_JOB_REPOSITORY='${DEFAULT_JOB_REPOSITORY}'." >> "${CONFIG_ERROR_FILE}"
  fi
  if [ -n "${TIMER_SERVICE_DATA_STORE}" ] && [ ! -f "${TIMER_SERVICE_DATA_STORE_FILE}" ]; then
    echo "The list of configured datasources does not contain a datasource matching the timer-service datastore datasource specified with TIMER_SERVICE_DATA_STORE='${TIMER_SERVICE_DATA_STORE}'." >> "${CONFIG_ERROR_FILE}"
  fi
  if [ -n "${EE_DEFAULT_DATASOURCE}" ] && [ ! -f "${EE_DEFAULT_DATASOURCE_FILE}" ]; then
    echo "The list of configured datasources does not contain a datasource matching the ee default-bindings datasource specified with EE_DEFAULT_DATASOURCE='${EE_DEFAULT_DATASOURCE}'." >> "${CONFIG_ERROR_FILE}"
  fi

  # Handle timer service here for backward compatibility since this can both be added in the 'internal' and 'external' cases.
  # The default job repository and ee default datasource are currently added for the 'internal' case only
  if [ -z "${TIMER_SERVICE_DATA_STORE}" ]; then
    inject_default_timer_service
  fi
  # Add the CLI commands from file
  if [ -s "${TIMER_SERVICE_DATA_STORE_FILE}" ]; then
    # This will either be the one from the TIMER_SERVICE_DATA_STORE match, or the default one
    cat "${TIMER_SERVICE_DATA_STORE_FILE}" >> "${CLI_SCRIPT_FILE}"
  fi
}

function initTempFiles() {
  DEFAULT_JOB_REPOSITORY_FILE="/tmp/ds-default-job-repo"
  TIMER_SERVICE_DATA_STORE_FILE="/tmp/ds-timer-service-data-store"
  EE_DEFAULT_DATASOURCE_FILE="/tmp/ds-ee-default-datastore"
}

function inject_datasources() {
  inject_datasources_common
}

function generate_datasource() {
  local pool_name="${1}"
  local jndi_name="${2}"
  local username="${3}"
  local password="${4}"
  local host="${5}"
  local port="${6}"
  local databasename="${7}"
  local checker="${8}"
  local sorter="${9}"
  local driver="${10}"
  local service_name="${11}"
  local jta="${12}"
  local validate="${13}"
  local url="${14}"

  generate_datasource_common "${1}" "${2}" "${3}" "${4}" "${5}" "${6}" "${7}" "${8}" "${9}" "${10}" "${11}" "${12}" "${13}" "${14}"
}