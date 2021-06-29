#!/bin/bash

if [ "${SCRIPT_DEBUG}" = "true" ] ; then
    set -x
    echo "Script debugging is enabled, allowing bash commands and their arguments to be printed as they are executed"
fi

source $JBOSS_HOME/bin/launch/launch-common.sh
source $JBOSS_HOME/bin/launch/logging.sh

SERVER_CONFIG=${WILDFLY_SERVER_CONFIGURATION:-standalone.xml}
export CONFIG_FILE=$JBOSS_HOME/standalone/configuration/${SERVER_CONFIG}
LOGGING_FILE=$JBOSS_HOME/standalone/configuration/logging.properties

# CONFIG_ADJUSTMENT_MODE is the mode used to do the environment variable replacement.
# The values are:
# -none     - no adjustment should be done. This cam be forced if $CONFIG_IS_FINAL = true
#               is passed in when starting the container
# -xml      - adjustment will happen via the legacy xml marker replacement
# -cli      - adjustment will happen via cli commands
# -xml_cli  - adjustment will happen via xml marker replacement if the marker is found. If not,
#               it will happen via cli commands. This is the default if not set by a consumer.
#
# Handling of the meanings of this is done by the launch scripts doing the config adjustment.
# Consumers of this script are expected to set this value.
if [ -z "${CONFIG_ADJUSTMENT_MODE}" ]; then
  export CONFIG_ADJUSTMENT_MODE="xml_cli"
fi
if [ -n "${CONFIG_IS_FINAL}" ] && [ "${CONFIG_IS_FINAL^^}" = "TRUE" ]; then
    export CONFIG_ADJUSTMENT_MODE="none"
fi

function createConfigExecutionContext() {
  systime=$(date +%s)
  # This is the cli file generated
  export CLI_SCRIPT_FILE=/tmp/cli-script-$systime.cli
  # The property file used to pass variables to jboss-cli.sh
  export CLI_SCRIPT_PROPERTY_FILE=/tmp/cli-script-property-$systime.cli
  # This is the cli process output file
  export CLI_SCRIPT_OUTPUT_FILE=/tmp/cli-script-output-$systime.cli
  # This is the file used to log errors by the launch scripts
  export CONFIG_ERROR_FILE=/tmp/cli-script-error-$systime.cli
  # This is the file used to log warnings by the launch scripts
  export CONFIG_WARNING_FILE=/tmp/cli-warning-$systime.log

  # Ensure we start with clean files
  if [ -s "${CLI_SCRIPT_FILE}" ]; then
    echo -n "" > "${CLI_SCRIPT_FILE}"
  fi
  if [ -s "${CONFIG_ERROR_FILE}" ]; then
    echo -n "" > "${CONFIG_ERROR_FILE}"
  fi
  if [ -s "${CONFIG_WARNING_FILE}" ]; then
    echo -n "" > "${CONFIG_WARNING_FILE}"
  fi
  if [ -s "${CLI_SCRIPT_PROPERTY_FILE}" ]; then
    echo -n "" > "${CLI_SCRIPT_PROPERTY_FILE}"
  fi
  if [ -s "${CLI_SCRIPT_OUTPUT_FILE}" ]; then
    echo -n "" > "${CLI_SCRIPT_OUTPUT_FILE}"
  fi

  echo "error_file=${CONFIG_ERROR_FILE}" > "${CLI_SCRIPT_PROPERTY_FILE}"
  echo "warning_file=${CONFIG_WARNING_FILE}" >> "${CLI_SCRIPT_PROPERTY_FILE}"
}

createConfigExecutionContext

# The CLI file that could have been used in S2I phase to define dirvers
S2I_CLI_DRIVERS_FILE=${JBOSS_HOME}/bin/launch/drivers.cli

if [ -s "${S2I_CLI_DRIVERS_FILE}" ] && [ "${CONFIG_ADJUSTMENT_MODE,,}" != "cli" ]; then
# If we have content in S2I_CLI_DRIVERS_FILE and we are not in pure CLI mode, then
# the CLI operations generated in S2I will be processed at runtime
 cat "${S2I_CLI_DRIVERS_FILE}" > "${CLI_SCRIPT_FILE}"
else
  echo -n "" > "${S2I_CLI_DRIVERS_FILE}"
fi

function processErrorsAndWarnings() {
  if [ -s "${CONFIG_WARNING_FILE}" ]; then
    while IFS= read -r line
    do
      log_warning "$line"
    done < "${CONFIG_WARNING_FILE}"
  fi
  rm -f "${CONFIG_WARNING_FILE}"
  if [ -s "${CONFIG_ERROR_FILE}" ]; then
    echo "Error applying ${CLI_SCRIPT_FILE_FOR_EMBEDDED} CLI script. Embedded server started successfully. The Operations were executed but there were unexpected values. See list of errors in ${CONFIG_ERROR_FILE}"
    while IFS= read -r line
    do
      log_error "$line"
    done < "${CONFIG_ERROR_FILE}"
    return 1
  fi
  return 0
}

function exec_cli_scripts() {
  local script="$1"
  local stdOut="echo"

  if [ "${SCRIPT_DEBUG}" = "true" ]; then
    CLI_DEBUG="TRUE";
  fi

  # remove any empty line
  if [ -f "${script}" ]; then
    sed -i '/^$/d' $script
  fi

  if [ -s "${script}" ]; then

    # Dump the cli script file for debugging
    if [ "${CLI_DEBUG^^}" = "TRUE" ]; then

      log_info "================= CLI files debug ================="
      if [ -f "${script}" ]; then
        log_info "=========== CLI Script ${script} contents:"
        cat "${script}"
      else
        log_info "No CLI_SCRIPT_FILE file found ${script}"
      fi
      if [ -f "${CLI_SCRIPT_PROPERTY_FILE}" ]; then
        log_info "=========== ${CLI_SCRIPT_PROPERTY_FILE} contents:"
        cat "${CLI_SCRIPT_PROPERTY_FILE}"
      else
        log_info "No CLI_SCRIPT_PROPERTY_FILE file found ${CLI_SCRIPT_PROPERTY_FILE}"
      fi
    fi

    #Check we are able to use the jboss-cli.sh
    if ! [ -f "${JBOSS_HOME}/bin/jboss-cli.sh" ]; then
      log_error "Cannot find ${JBOSS_HOME}/bin/jboss-cli.sh. Scripts cannot be applied"
      exit 1
    fi

    systime=$(date +%s)
    CLI_SCRIPT_FILE_FOR_EMBEDDED=/tmp/cli-configuration-script-${systime}.cli
    echo "embed-server --timeout=30 --server-config=${SERVER_CONFIG} --std-out=${stdOut}" > ${CLI_SCRIPT_FILE_FOR_EMBEDDED}
    cat ${script} >> ${CLI_SCRIPT_FILE_FOR_EMBEDDED}
    echo "" >> ${CLI_SCRIPT_FILE_FOR_EMBEDDED}
    echo "stop-embedded-server" >> ${CLI_SCRIPT_FILE_FOR_EMBEDDED}

    log_info "Configuring the server using embedded server"
    start=$(date +%s%3N)
    eval ${JBOSS_HOME}/bin/jboss-cli.sh "--file=${CLI_SCRIPT_FILE_FOR_EMBEDDED}" "--properties=${CLI_SCRIPT_PROPERTY_FILE}" "&>${CLI_SCRIPT_OUTPUT_FILE}"
    cli_result=$?
    end=$(date +%s%3N)

    if [ "${SCRIPT_DEBUG}" == "true" ] ; then
      cat "${CLI_SCRIPT_OUTPUT_FILE}"
    fi

    log_info "Duration: $((end-start)) milliseconds"

    if [ $cli_result -ne 0 ]; then
      log_error "Error applying ${CLI_SCRIPT_FILE_FOR_EMBEDDED} CLI script."
      cat "${CLI_SCRIPT_OUTPUT_FILE}"
      exit 1
    else
      processErrorsAndWarnings
      if [ $? -ne 0 ]; then
        exit 1
      fi
      if [ "${SCRIPT_DEBUG}" != "true" ] ; then
        rm ${script} 2> /dev/null
        rm ${CLI_SCRIPT_PROPERTY_FILE} 2> /dev/null
        rm ${CONFIG_ERROR_FILE} 2> /dev/null
        rm ${CONFIG_WARNING_FILE} 2> /dev/null
        rm ${CLI_SCRIPT_FILE_FOR_EMBEDDED} 2> /dev/null
        rm ${CLI_SCRIPT_OUTPUT_FILE} 2> /dev/null
      fi
    fi
  else
    if [ "${CLI_DEBUG^^}" = "TRUE" ]; then
      log_info "================= CLI files debug ================="
      log_info "No CLI commands were found in ${script}"
    fi
  fi

  if [ "${SCRIPT_DEBUG}" = "true" ] ; then
    log_info "CLI Script used to configure the server: ${CLI_SCRIPT_FILE_FOR_EMBEDDED}"
    log_info "CLI Script generated by launch: ${CLI_SCRIPT_FILE}"
    log_info "CLI Script property file: ${CLI_SCRIPT_PROPERTY_FILE}"
    log_info "CLI Script error file: ${CONFIG_ERROR_FILE}"
    log_info "CLI Script output file: ${CLI_SCRIPT_OUTPUT_FILE}"
  fi
}
