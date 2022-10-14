#!/usr/bin/env bash
# Openshift EAP launch script

if [ "${SCRIPT_DEBUG}" = "true" ] ; then
    set -x
    echo "Script debugging is enabled, allowing bash commands and their arguments to be printed as they are executed"
fi

# RHSSO-2211 Import common EAP launch routines
source "${JBOSS_HOME}/bin/launch/launch-common.sh"
# RHSSO-2211 Import common RH-SSO global variables & functions
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

# Escape XML special characters possibly present in values of
# selected environment variables with their XML entity counterparts
sanitize_shell_env_vars_to_valid_xml_values

export CONFIG_FILE="${JBOSS_HOME}/standalone/configuration/standalone-openshift.xml"
export LOGGING_FILE="${JBOSS_HOME}/standalone/configuration/logging.properties"

# Define various CLI_SCRIPT_* variables required by EAP configure scripts
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

#For backward compatibility
ADMIN_USERNAME=${ADMIN_USERNAME:-${EAP_ADMIN_USERNAME:-$DEFAULT_ADMIN_USERNAME}}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-$EAP_ADMIN_PASSWORD}
NODE_NAME=${NODE_NAME:-$EAP_NODE_NAME}
HTTPS_NAME=${HTTPS_NAME:-$EAP_HTTPS_NAME}
HTTPS_PASSWORD=${HTTPS_PASSWORD:-$EAP_HTTPS_PASSWORD}
HTTPS_KEYSTORE_DIR=${HTTPS_KEYSTORE_DIR:-$EAP_HTTPS_KEYSTORE_DIR}
HTTPS_KEYSTORE=${HTTPS_KEYSTORE:-$EAP_HTTPS_KEYSTORE}
SECDOMAIN_USERS_PROPERTIES=${SECDOMAIN_USERS_PROPERTIES:-${EAP_SECDOMAIN_USERS_PROPERTIES:-users.properties}}
SECDOMAIN_ROLES_PROPERTIES=${SECDOMAIN_ROLES_PROPERTIES:-${EAP_SECDOMAIN_ROLES_PROPERTIES:-roles.properties}}
SECDOMAIN_NAME=${SECDOMAIN_NAME:-$EAP_SECDOMAIN_NAME}
SECDOMAIN_PASSWORD_STACKING=${SECDOMAIN_PASSWORD_STACKING:-$EAP_SECDOMAIN_PASSWORD_STACKING}

export IMPORT_REALM_FILE="${JBOSS_HOME}/standalone/configuration/import-realm.json"

export CONFIGURE_SCRIPTS=(
  "${JBOSS_HOME}/bin/launch/configure_extensions.sh"
  # The nss_wrapper_passwd.sh module below can be removed altogether once Red Hat
  # Single Sign-On 7 OpenShift container images don't need to support OpenShift v3.x.
  # See comment in the module itself for further details.
  "${JBOSS_HOME}/bin/launch/nss_wrapper_passwd.sh"
  "${JBOSS_HOME}/bin/launch/datasource.sh"
  "${JBOSS_HOME}/bin/launch/resource-adapter.sh"
  "${JBOSS_HOME}/bin/launch/admin.sh"
  "${JBOSS_HOME}/bin/launch/ha.sh"
  "${JBOSS_HOME}/bin/launch/openshift-x509.sh"
  "${JBOSS_HOME}/bin/launch/elytron.sh"
  # jgroups.sh requires elytron.sh as it uses some functions elytron.sh defines
  "${JBOSS_HOME}/bin/launch/jgroups.sh"
  "${JBOSS_HOME}/bin/launch/https.sh"
  "${JBOSS_HOME}/bin/launch/json_logging.sh"
  "${JBOSS_HOME}/bin/launch/security-domains.sh"
  "${JBOSS_HOME}/bin/launch/jboss_modules_system_pkgs.sh"
  "${JBOSS_HOME}/bin/launch/deploymentScanner.sh"
  "${JBOSS_HOME}/bin/launch/ports.sh"
  "${JBOSS_HOME}/bin/launch/add-sso-admin-user.sh"
  "${JBOSS_HOME}/bin/launch/add-sso-realm.sh"
  "${JBOSS_HOME}/bin/launch/keycloak-spi.sh"
  "${JBOSS_HOME}/bin/launch/access_log_valve.sh"
  "${JBOSS_HOME}/bin/launch/configure_sso_cli_extensions.sh"
  "${JBOSS_HOME}/bin/launch/sso_image_pre_launch_checks.sh"
  /opt/run-java/proxy-options
)
