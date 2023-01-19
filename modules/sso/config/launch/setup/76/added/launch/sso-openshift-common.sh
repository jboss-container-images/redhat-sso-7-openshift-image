#!/usr/bin/env bash
#
# Openshift RH-SSO container image main configuration script
#
# Used to configure values of environment variables important to RH-SSO container image
# and to define the list of configure scripts (see the CONFIGURE_SCRIPTS array definition
# below) to be executed upon RH-SSO container start and the order of their execution

if [ "${SCRIPT_DEBUG}" = "true" ] ; then
    set -x
    echo "Script debugging is enabled, allowing bash commands and their arguments to be printed as they are executed"
fi

# RHSSO-2211 Import common EAP launch routines
# shellcheck disable=SC1091
source "${JBOSS_HOME}/bin/launch/launch-common.sh"
# RHSSO-2211 Import common RH-SSO global variables & functions
# shellcheck disable=SC1091
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

# RHSSO-1953 Import main OpenShift common script from EAP layer first
# To define certain variables and functions later re-used by the RH-SSO image
# shellcheck disable=SC1091
source "${JBOSS_HOME}/bin/launch/openshift-common.sh"
# But reset / redefine the values of selected environment variables so they
# correspond to the needs of RH-SSO container image (rather than to EAP one)
export SERVER_CONFIG="standalone-openshift.xml"
export CONFIG_FILE="${JBOSS_HOME}/standalone/configuration/${SERVER_CONFIG}"
export IMPORT_REALM_FILE="${JBOSS_HOME}/standalone/configuration/import-realm.json"
export LOGGING_FILE="${JBOSS_HOME}/standalone/configuration/logging.properties"

# Escape XML special characters possibly present in values of
# selected environment variables with their XML entity counterparts
sanitize_shell_env_vars_to_valid_xml_values

# For backward compatibility
NODE_NAME=${NODE_NAME:-$EAP_NODE_NAME}
HTTPS_NAME=${HTTPS_NAME:-$EAP_HTTPS_NAME}
HTTPS_PASSWORD=${HTTPS_PASSWORD:-$EAP_HTTPS_PASSWORD}
HTTPS_KEYSTORE_DIR=${HTTPS_KEYSTORE_DIR:-$EAP_HTTPS_KEYSTORE_DIR}
HTTPS_KEYSTORE=${HTTPS_KEYSTORE:-$EAP_HTTPS_KEYSTORE}
SECDOMAIN_USERS_PROPERTIES=${SECDOMAIN_USERS_PROPERTIES:-${EAP_SECDOMAIN_USERS_PROPERTIES:-users.properties}}
SECDOMAIN_ROLES_PROPERTIES=${SECDOMAIN_ROLES_PROPERTIES:-${EAP_SECDOMAIN_ROLES_PROPERTIES:-roles.properties}}
SECDOMAIN_NAME=${SECDOMAIN_NAME:-$EAP_SECDOMAIN_NAME}
SECDOMAIN_PASSWORD_STACKING=${SECDOMAIN_PASSWORD_STACKING:-$EAP_SECDOMAIN_PASSWORD_STACKING}

export CONFIGURE_SCRIPTS=(
  "${JBOSS_HOME}/bin/launch/configure_extensions.sh"
  # The nss_wrapper_passwd.sh module below can be removed altogether once Red Hat
  # Single Sign-On 7 OpenShift container images don't need to support OpenShift v3.x.
  # See comment in the module itself for further details.
  "${JBOSS_HOME}/bin/launch/nss_wrapper_passwd.sh"
  "${JBOSS_HOME}/bin/launch/datasource.sh"
  "${JBOSS_HOME}/bin/launch/resource-adapter.sh"
  "${JBOSS_HOME}/bin/launch/mgmt_iface.sh"
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
