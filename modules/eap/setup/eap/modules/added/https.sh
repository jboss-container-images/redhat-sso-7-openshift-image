#!/bin/sh
# only processes a single environment as the placeholder is not preserved

source $JBOSS_HOME/bin/launch/logging.sh

function prepareEnv() {
  unset HTTPS_NAME
  unset HTTPS_PASSWORD
  unset HTTPS_KEYSTORE_DIR
  unset HTTPS_KEYSTORE
  unset HTTPS_KEYSTORE_TYPE
}

function configure() {
  configure_https
}

function configureEnv() {
  configure
}

function configure_https() {
  if [ "${CONFIGURE_ELYTRON_SSL}" = "true" ]; then
    log_info "Using Elytron for SSL configuration."
    return
  fi

  local sslConfMode
  getConfigurationMode "<!-- ##SSL## -->" "sslConfMode"

  local httpsConfMode
  getConfigurationMode "<!-- ##HTTPS_CONNECTOR## -->" "httpsConfMode"


  if [ -n "${HTTPS_PASSWORD}" -a -n "${HTTPS_KEYSTORE_DIR}" -a -n "${HTTPS_KEYSTORE}" ]; then

    if [ "${sslConfMode}" = "xml" ]; then
      configureSslXml
    elif [ "${sslConfMode}" = "cli" ]; then
      configureSslCli
    fi

    if [ "${httpsConfMode}" = "xml" ]; then
      configureHttpsXml
    elif [ "${httpsConfMode}" = "cli" ]; then
      configureHttpsCli
    fi

  elif [ -n "${HTTPS_PASSWORD}" -o -n "${HTTPS_KEYSTORE_DIR}" -o -n "${HTTPS_KEYSTORE}" ]; then
    log_warning "Partial HTTPS configuration, the https connector WILL NOT be configured."

    if [ "${sslConfMode}" = xml ]; then
      sed -i "s|<!-- ##SSL## -->|<!-- No SSL configuration discovered -->|" $CONFIG_FILE
    fi

    if [ "${httpsConfMode}" = xml ]; then
      sed -i "s|<!-- ##HTTPS_CONNECTOR## -->|<!-- No HTTPS configuration discovered -->|" $CONFIG_FILE
    fi
  fi
}

function configureSslXml() {
  if [ -n "$HTTPS_KEYSTORE_TYPE" ]; then
    keystore_provider="provider=\"${HTTPS_KEYSTORE_TYPE}\""
  fi
  ssl="<server-identities>\n\
            <ssl>\n\
                <keystore ${keystore_provider} path=\"${HTTPS_KEYSTORE_DIR}/${HTTPS_KEYSTORE}\" keystore-password=\"${HTTPS_PASSWORD}\"/>\n\
            </ssl>\n\
        </server-identities>"

  sed -i "s|<!-- ##SSL## -->|${ssl}|" $CONFIG_FILE
}

function configureSslCli() {
  local app_realm_resource="/core-service=management/security-realm=ApplicationRealm"
  local ssl_resource="${app_realm_resource}/server-identity=ssl"
  local ssl_add="$ssl_resource:add(keystore-path=\"${HTTPS_KEYSTORE_DIR}/${HTTPS_KEYSTORE}\", keystore-password=\"${HTTPS_PASSWORD}\""
  if [ -n "$HTTPS_KEYSTORE_TYPE" ]; then
    ssl_add="${ssl_add}, keystore-provider=\"${HTTPS_KEYSTORE_TYPE}\""
  fi
  ssl_add="${ssl_add})"

  cat << EOF >> ${CLI_SCRIPT_FILE}
  if (outcome != success) of ${app_realm_resource}:read-resource
    echo You have set the HTTPS_PASSWORD, HTTPS_KEYSTORE_DIR and HTTPS_KEYSTORE to add the ssl server-identity. Fix your configuration to contain the ${app_realm_resource} resource for this to happen. >> \${error_file}
    exit
  end-if
  if (outcome == success) of ${ssl_resource}:read-resource
    echo You have set the HTTPS_PASSWORD, HTTPS_KEYSTORE_DIR and HTTPS_KEYSTORE to add the ssl server-identity. But this already exists in the base configuration. Fix your configuration. >> \${error_file}
    exit
  end-if
  ${ssl_add}
EOF
}

function configureHttpsXml() {
  https_connector="<https-listener name=\"https\" socket-binding=\"https\" security-realm=\"ApplicationRealm\" proxy-address-forwarding=\"true\"/>"
  sed -i "s|<!-- ##HTTPS_CONNECTOR## -->|${https_connector}|" $CONFIG_FILE
}

function configureHttpsCli() {
    # No subsystem is an error
    local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:undertow:')]\""
    local ssRet
    testXpathExpression "${xpath}" "ssRet"
    if [ "${ssRet}" -ne 0 ]; then
      echo "You have set HTTPS_PASSWORD, HTTPS_KEYSTORE_DIR and HTTPS_KEYSTORE to add an undertow https-listener. Fix your configuration to contain the undertow subsystem for this to happen." >> "${CONFIG_ERROR_FILE}"
      return
    fi

    # Not having any servers is an error
    local serverNamesRet
    # We grab the <server name="..."> attributes, and will use them later
    local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:undertow:')]/*[local-name()='server']/@name\""
    testXpathExpression "${xpath}" "serverNamesRet"
    if [ "${serverNamesRet}" -ne 0 ]; then
      echo "You have set HTTPS_PASSWORD, HTTPS_KEYSTORE_DIR and HTTPS_KEYSTORE to add an undertow https-listener. Fix your configuration to contain at least one server in the undertow subsystem for this to happen." >> ${CONFIG_ERROR_FILE}
      return
    fi

    # Existing https-listener(s) is an error
    local httpsListenersRet
    local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:undertow:')]/*[local-name()='server']/*[local-name()='https-listener']/@name\""
    testXpathExpression "${xpath}" "httpsListenersRet"
    if [ "${httpsListenersRet}" -eq 0 ]; then
      echo "You have set HTTPS_PASSWORD, HTTPS_KEYSTORE_DIR and HTTPS_KEYSTORE to add https-listeners to your undertow servers, however at least one of these already contains an https-listener. Fix your configuration." >> "${CONFIG_ERROR_FILE}"
      return
    fi

    cat << EOF >> ${CLI_SCRIPT_FILE}
    for serverName in /subsystem=undertow:read-children-names(child-type=server)
      /subsystem=undertow/server=\$serverName/https-listener=https:add(security-realm=ApplicationRealm, socket-binding=https, proxy-address-forwarding=true)
    done
EOF

}