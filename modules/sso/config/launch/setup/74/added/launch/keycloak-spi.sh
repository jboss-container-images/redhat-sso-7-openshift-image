#!/bin/bash

# Import logging module
source $JBOSS_HOME/bin/launch/logging.sh

function prepareEnv() {
  unset SSO_TRUSTSTORE
  unset SSO_TRUSTSTORE_DIR
  unset SSO_TRUSTSTORE_PASSWORD
}

function configure() {
  add_truststore
  # KEYCLOAK-8129 Set Keycloak server's hostname to 'request' by default if SSO_HOSTNAME not set
  set_server_hostname_spi_to_request
}

function add_truststore() {
  
  if [ -n "$SSO_TRUSTSTORE" ] && [ -n "$SSO_TRUSTSTORE_DIR" ] && [ -n "$SSO_TRUSTSTORE_PASSWORD" ]; then

    local truststore="<spi name=\"truststore\"><provider name=\"file\" enabled=\"true\"><properties><property name=\"file\" value=\"${SSO_TRUSTSTORE_DIR}/${SSO_TRUSTSTORE}\"/><property name=\"password\" value=\"${SSO_TRUSTSTORE_PASSWORD}\"/><property name=\"hostname-verification-policy\" value=\"WILDCARD\"/><property name=\"disabled\" value=\"false\"/></properties></provider></spi>"

    sed -i "s|<!-- ##SSO_TRUSTSTORE## -->|${truststore}|" "${CONFIG_FILE}"

  fi
}

# KEYCLOAK-8129 Set Keycloak server's hostname to 'request' by default if SSO_HOSTNAME not set
function set_server_hostname_spi_to_request() {

  if [ -z "${SSO_HOSTNAME}" ]; then

    local -r hostname_spi="<spi name=\"hostname\"><default-provider>request</default-provider><provider name=\"fixed\" enabled=\"true\"><properties><property name=\"hostname\" value=\"localhost\"/><property name=\"httpPort\" value=\"-1\"/><property name=\"httpsPort\" value=\"-1\"/></properties></provider></spi>"

    sed -i "s|<!-- ##SSO_SERVER_HOSTNAME_SPI## -->|${hostname_spi}|" "${CONFIG_FILE}"

  fi
}

# KEYCLOAK-8129 Set Keycloak server's hostname to 'fixed' with hostname matching supplied parameter if SSO_HOSTNAME set
function set_server_hostname_spi_to_fixed() {

  if [ -n "${SSO_HOSTNAME}" ]; then

    if [ "$#" -ne 1 ]; then
      log_warning "Hostname is required for ${FUNCNAME[0]}. Please specify a hostname to use for the configuration of 'fixed' hostname SPI."
      exit 1
    fi

    local -r requested_hostname="$1"
    local -r hostname_spi="<spi name=\"hostname\"><default-provider>fixed</default-provider><provider name=\"fixed\" enabled=\"true\"><properties><property name=\"hostname\" value=\"${requested_hostname}\"/><property name=\"httpPort\" value=\"-1\"/><property name=\"httpsPort\" value=\"-1\"/></properties></provider></spi>"

    sed -i "s|<!-- ##SSO_SERVER_HOSTNAME_SPI## -->|${hostname_spi}|" "${CONFIG_FILE}"

  fi
}
