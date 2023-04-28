#!/bin/bash

# Import logging module
source $JBOSS_HOME/bin/launch/logging.sh

# RHSSO-2211 Import common RH-SSO global variables & functions
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

function prepareEnv() {
  unset SSO_TRUSTSTORE
  unset SSO_TRUSTSTORE_DIR
  unset SSO_TRUSTSTORE_PASSWORD
  unset SSO_VAULT_DIR
}

function configure() {
  add_truststore
  add_vault
  # KEYCLOAK-8129 Set Keycloak server's hostname to 'request' by default if SSO_HOSTNAME not set
  set_server_hostname_spi_to_default
}

function add_truststore() {
  if [ -n "$SSO_TRUSTSTORE" ] && [ -n "$SSO_TRUSTSTORE_DIR" ] && [ -n "$SSO_TRUSTSTORE_PASSWORD" ]; then

    local truststore="<spi name=\"truststore\"><provider name=\"file\" enabled=\"true\"><properties><property name=\"file\" value=\"${SSO_TRUSTSTORE_DIR}/${SSO_TRUSTSTORE}\"/><property name=\"password\" value=\"${SSO_TRUSTSTORE_PASSWORD}\"/><property name=\"hostname-verification-policy\" value=\"WILDCARD\"/><property name=\"disabled\" value=\"false\"/></properties></provider></spi>"

    # RHSSO-2017 Escape possible ampersand and semicolong characters
    # which are interpolated when used in sed righ-hand side expression
    truststore=$(escape_sed_rhs_interpolated_characters "${truststore}")
    # EOF RHSSO-2017 correction
    # CIAM-1394 correction
    sed -i "s${AUS}<!-- ##SSO_TRUSTSTORE## -->${AUS}${truststore}${AUS}" "${CONFIG_FILE}"
    # EOF CIAM-1394 correction

  fi
}

function add_vault() {

  if [ -n "$SSO_VAULT_DIR" ]; then

    local vault="<spi name=\"vault\"><default-provider>files-plaintext</default-provider><provider name=\"files-plaintext\" enabled=\"true\"><properties><property name=\"dir\" value=\"${SSO_VAULT_DIR}\"/></properties></provider></spi>"
    # RHSSO-2017 Escape possible ampersand and semicolong characters
    # which are interpolated when used in sed righ-hand side expression
    vault=$(escape_sed_rhs_interpolated_characters "${vault}")
    # EOF RHSSO-2017 correction
    # CIAM-1394 correction
    sed -i "s${AUS}<!-- ##SSO_VAULT_CONFIG## -->${AUS}${vault}${AUS}" "${CONFIG_FILE}"
    # EOF CIAM-1394 correction
  fi
}

# KEYCLOAK-8129 Set Keycloak server's hostname to 'default' by default if SSO_HOSTNAME not set
function set_server_hostname_spi_to_default() {

  if [ -z "${SSO_HOSTNAME}" ]; then

    local properties=''
    if [ -n "${SSO_FRONTEND_URL:-$KEYCLOAK_FRONTEND_URL}" ]; then
        properties+="<property name=\"frontendUrl\" value=\"${SSO_FRONTEND_URL:-$KEYCLOAK_FRONTEND_URL}\"/>"
        # RHSSO-2017 Escape possible ampersand and semicolong characters
        # which are interpolated when used in sed righ-hand side expression
        properties=$(escape_sed_rhs_interpolated_characters "${properties}")
        # EOF RHSSO-2017 correction
    fi
    local -r hostname_spi="<spi name=\"hostname\"><default-provider>default</default-provider><provider name=\"default\" enabled=\"true\"><properties>${properties}</properties></provider></spi>"

    # CIAM-1394 correction
    sed -i "s${AUS}<!-- ##SSO_SERVER_HOSTNAME_SPI## -->${AUS}${hostname_spi}${AUS}" "${CONFIG_FILE}"
    # EOF CIAM-1394 correction

  fi
}

# KEYCLOAK-8129 Set Keycloak server's hostname to 'fixed' with hostname matching supplied parameter if SSO_HOSTNAME set
function set_server_hostname_spi_to_fixed() {

  if [ -n "${SSO_HOSTNAME}" ]; then

    if [ "$#" -ne 1 ]; then
      log_warning "Hostname is required for ${FUNCNAME[0]}. Please specify a hostname to use for the configuration of 'fixed' hostname SPI."
      exit 1
    fi

    local requested_hostname="$1"
    # RHSSO-2017 Escape possible ampersand and semicolong characters
    # which are interpolated when used in sed righ-hand side expression
    requested_hostname=$(escape_sed_rhs_interpolated_characters "${requested_hostname}")
    # EOF RHSSO-2017 correction

    local -r hostname_spi="<spi name=\"hostname\"><default-provider>fixed</default-provider><provider name=\"fixed\" enabled=\"true\"><properties><property name=\"hostname\" value=\"${requested_hostname}\"/><property name=\"httpPort\" value=\"-1\"/><property name=\"httpsPort\" value=\"-1\"/><property name=\"alwaysHttps\" value=\"false\"/></properties></provider></spi>"

    # CIAM-1394 correction
    sed -i "s${AUS}<!-- ##SSO_SERVER_HOSTNAME_SPI## -->${AUS}${hostname_spi}${AUS}" "${CONFIG_FILE}"
    # EOF CIAM-1394 correction

  fi
}
