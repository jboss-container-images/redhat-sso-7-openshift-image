# only processes a single environment as the placeholder is not preserved

prepareEnv() {
  unset HTTPS_NAME
  unset HTTPS_PASSWORD
  unset HTTPS_KEY_PASSWORD
  unset HTTPS_KEYSTORE_DIR
  unset HTTPS_KEYSTORE
  unset HTTPS_KEYSTORE_TYPE
}

configure() {
  configure_https
  configure_security_domains
}

configureEnv() {
  configure
}

has_elytron_tls() {
    declare config_file="$1"
    if grep -q '<!-- ##ELYTRON_TLS## -->' "${config_file}"
    then
        echo "true"
    else
        echo "false"
    fi
}

has_elytron_legacy_tls() {
    declare config_file="$1"
    if grep -q '<!-- ##TLS## -->' "${config_file}"
    then
        echo "true"
    else
        echo "false"
    fi
}

has_elytron_keystore() {
    declare config_file="$1"
    if grep -q '<!-- ##ELYTRON_KEY_STORE## -->' "${config_file}"
    then
        echo "true"
    else
        echo "false"
    fi
}

insert_elytron_tls() {
 # the elytron skelton config. This will be used to replace <!-- ##ELYTRON_TLS## -->
 # if this is replaced, we'll also remove the legacy <!-- ##TLS## --> marker
 local elytron_tls="         <tls>\n\
            <key-stores>\n\
                <!-- ##ELYTRON_KEY_STORE## -->\n\
            </key-stores>\n\
            <key-managers>\n\
                <!-- ##ELYTRON_KEY_MANAGER## -->\n\
            </key-managers>\n\
            <server-ssl-contexts>\n\
                <!-- ##ELYTRON_SERVER_SSL_CONTEXT## -->\n\
            </server-ssl-contexts>\n\
         </tls>\n"
    # check for new config tag, use that if it's present, note we remove the <!-- ##ELYTRON_TLS## --> on first substitution
    if [ "true" = $(has_elytron_tls "${CONFIG_FILE}") ]; then
        sed -i "s|<!-- ##ELYTRON_TLS## -->|${elytron_tls}|" $CONFIG_FILE
        # remove the legacy tag, if it's present
        sed -i "s|<!-- ##TLS## -->||" $CONFIG_FILE
    fi
}

insert_elytron_tls_config_if_needed() {
    declare config_file="$1"
    if [ "$(has_elytron_tls "${config_file}")" = "true" ] || [ "$(has_elytron_keystore "${config_file}")" = "true" ]; then
        # insert the new config element, only if it hasn't been added already
        if [ "$(has_elytron_keystore "${config_file}")" = "false" ]; then
            insert_elytron_tls
        fi
    fi
}

elytron_legacy_config() {
    declare elytron_keystore="$1" elytron_key_manager="$2" elytron_server_ssl_context="$3"
    # this is to support the legacy <!-- ##TLS## --> insertion block.
    local legacy_elytron_tls="\
    <tls>\n\
        <key-stores>\n\
            ${elytron_key_store}\n\
        </key-stores>\n\
        <key-managers>\n\
            ${elytron_key_manager}\n\
        </key-managers>\n\
        <server-ssl-contexts>\n\
            ${elytron_server_ssl_context}\n\
        </server-ssl-contexts>\n\
    </tls>"

   echo ${legacy_elytron_tls}
}

create_elytron_keystore() {
    declare encrypt_keystore_name="$1" encrypt_keystore="$2" encrypt_password="$3" encrypt_keystore_type="$4" encrypt_keystore_dir="$5"

    local keystore_path=""
    local keystore_rel_to=""

    # if encrypt_keystore_dir is null, we assume the keystore is relative to the servers jboss.server.config.dir
    if [ -z "${encrypt_keystore_dir}" ]; then
      # Documented behavior; HTTPS_KEYSTORE is relative to the config dir
      # Use case is the user puts their keystore in their source's 'configuration' dir and s2i pulls it in
      keystore_path="path=\"${encrypt_keystore}\""
      keystore_rel_to="relative-to=\"jboss.server.config.dir\""
    elif [[ "${encrypt_keystore_dir}" =~ ^/ ]]; then
      # Assume leading '/' means the value is a FS path
      # Standard template behavior where the template sets this var to /etc/eap-secret-volume
      keystore_path="path=\"${encrypt_keystore_dir}/${encrypt_keystore}\""
      keystore_rel_to=""
    else
      # Compatibility edge case. Treat no leading '/' as meaning HTTPS_KEYSTORE_DIR is the name of a config model path
      keystore_path="path=\"${encrypt_keystore}\""
      keystore_rel_to="relative-to=\"${encrypt_keystore_dir}\""
    fi

    local key_store="<key-store name=\"${encrypt_keystore_name}\">\n\
              <credential-reference clear-text=\"${encrypt_password}\"/>\n\
              <implementation type=\"${encrypt_keystore_type:-JCEKS}\"/>\n\
              <file ${keystore_path} ${keystore_rel_to} />\n\
            </key-store>"
    echo ${key_store}
}

create_elytron_keymanager() {
    declare key_manager="$1" key_store="$2" key_password="$3"
    # note key password here may be the same as the password to the keystore itself, or a seperate key specific password.
    # in either case it is required.
    local key_password="<credential-reference clear-text=\"${key_password}\"/>"
    local elytron_keymanager="<key-manager name=\"${key_manager}\" key-store=\"${key_store}\">$key_password</key-manager>"
    echo ${elytron_keymanager}
}

create_elytron_ssl_context() {
    declare ssl_context_name="$1" key_manager_name="$2"
    echo "<server-ssl-context name=\"${ssl_context_name}\" key-manager=\"${key_manager_name}\"/>"
}

create_elytron_https_connector() {
    declare name="$1" socket_binding="$2" ssl_context="$3" proxy_address_forwarding="$4"
    echo "<https-listener name=\"${name}\" socket-binding=\"${socket_binding}\" ssl-context=\"${ssl_context}\" proxy-address-forwarding=\"${proxy_address_forwarding:-true}\"/>"
}

configure_https() {

  if [ "${CONFIGURE_ELYTRON_SSL}" != "true" ]; then
    echo "Using PicketBox SSL configuration."
    return 
  fi

  local ssl="<!-- No SSL configuration discovered -->"
  local https_connector="<!-- No HTTPS configuration discovered -->"
  local missing_msg="WARNING! Partial HTTPS configuration, the https connector WILL NOT be configured. Missing:"
  local key_password=""
  local elytron_key_store=""
  local elytron_key_manager=""
  local elytron_server_ssl_context=""
  local elytron_https_connector=""

  if [ -n "${HTTPS_PASSWORD}" -a -n "${HTTPS_KEYSTORE}" -a -n "${HTTPS_KEYSTORE_TYPE}" ]; then
    if [ -n "${HTTPS_KEY_PASSWORD}" ]; then
      key_password="${HTTPS_KEY_PASSWORD}"
    else
      echo "No HTTPS_KEY_PASSWORD was provided; using HTTPS_PASSWORD for Elytron LocalhostKeyManager."
      key_password="${HTTPS_PASSWORD}"
    fi

    local elytron_key_store=$(create_elytron_keystore "LocalhostKeyStore" "${HTTPS_KEYSTORE}" "${HTTPS_PASSWORD}" "${HTTPS_KEYSTORE_TYPE}" "${HTTPS_KEYSTORE_DIR}")
    local elytron_key_manager=$(create_elytron_keymanager "LocalhostKeyManager" "LocalhostKeyStore" "${key_password}")
    local elytron_server_ssl_context=$(create_elytron_ssl_context "LocalhostSslContext" "LocalhostKeyManager")
    local elytron_https_connector=$(create_elytron_https_connector "https" "https" "LocalhostSslContext" "true")

    # check for new config tag, use that if it's present, also allow for the fact that somethign else has already replaced it
    if [ "$(has_elytron_tls "${CONFIG_FILE}")" = "true" ] || [ "$(has_elytron_keystore "${CONFIG_FILE}")" = "true" ]; then
        # insert the new config element, only if it hasn't been added already
        insert_elytron_tls_config_if_needed "${CONFIG_FILE}"
        # insert the individual config blocks we leave the replacement tags around in case something else (e.g. jgoups might need to add a keystore etc)
        sed -i "s|<!-- ##ELYTRON_KEY_STORE## -->|${elytron_key_store}<!-- ##ELYTRON_KEY_STORE## -->|" $CONFIG_FILE
        sed -i "s|<!-- ##ELYTRON_KEY_MANAGER## -->|${elytron_key_manager}<!-- ##ELYTRON_KEY_MANAGER## -->|" $CONFIG_FILE
        sed -i "s|<!-- ##ELYTRON_SERVER_SSL_CONTEXT## -->|${elytron_server_ssl_context}<!-- ##ELYTRON_SERVER_SSL_CONTEXT## -->|" $CONFIG_FILE
    else # legacy config
        legacy_elytron_tls=$(elytron_legacy_config "${elytron_key_store}" "${elytron_key_manager}" "${elytron_server_ssl_context}")
    fi
    # will be empty unless only the old marker is present.
    sed -i "s|<!-- ##TLS## -->|${legacy_elytron_tls}|" $CONFIG_FILE
    sed -i "s|<!-- ##HTTPS_CONNECTOR## -->|${elytron_https_connector}|" $CONFIG_FILE
  else
    if [ -z "${HTTPS_PASSWORD}" ]; then
      missing_msg="$missing_msg HTTPS_PASSWORD"
    fi
    if [ -z "${HTTPS_KEYSTORE}" ]; then
      missing_msg="$missing_msg HTTPS_KEYSTORE"
    fi
    if [ -z "${HTTPS_KEYSTORE_TYPE}" ]; then
      missing_msg="$missing_msg HTTPS_KEYSTORE_TYPE"
    fi
    echo ${missing_msg}
  fi
}

configure_security_domains() {
  if [ -n "${SECDOMAIN_NAME}" ]; then
    elytron_integration="<elytron-integration>\n\
                <security-realms>\n\
                    <elytron-realm name=\"${SECDOMAIN_NAME}\" legacy-jaas-config=\"${SECDOMAIN_NAME}\"/>\n\
                </security-realms>\n\
            </elytron-integration>"
    ejb_application_security_domains="<application-security-domains>\n\
                <application-security-domain name=\"${SECDOMAIN_NAME}\" security-domain=\"${SECDOMAIN_NAME}\"/>\n\
            </application-security-domains>"
    http_application_security_domains="<application-security-domains>\n\
                <application-security-domain name=\"${SECDOMAIN_NAME}\" http-authentication-factory=\"${SECDOMAIN_NAME}-http\"/>\n\
            </application-security-domains>"
    http_authentication_factory="<http-authentication-factory name=\"${SECDOMAIN_NAME}-http\" http-server-mechanism-factory=\"global\" security-domain=\"${SECDOMAIN_NAME}\">\n\
                    <mechanism-configuration>\n\
                        <mechanism mechanism-name=\"BASIC\"/>\n\
                        <mechanism mechanism-name=\"FORM\"/>\n\
                    </mechanism-configuration>\n\
                </http-authentication-factory>"
    elytron_security_domain="<security-domain name=\"${SECDOMAIN_NAME}\" default-realm=\"${SECDOMAIN_NAME}\" permission-mapper=\"default-permission-mapper\">\n\
                    <realm name=\"${SECDOMAIN_NAME}\"/>\n\
                </security-domain>"
  fi

  sed -i "s|<!-- ##ELYTRON_INTEGRATION## -->|${elytron_integration}|" $CONFIG_FILE
  sed -i "s|<!-- ##EJB_APPLICATION_SECURITY_DOMAINS## -->|${ejb_application_security_domains}|" $CONFIG_FILE
  sed -i "s|<!-- ##HTTP_APPLICATION_SECURITY_DOMAINS## -->|${http_application_security_domains}|" $CONFIG_FILE
  sed -i "s|<!-- ##HTTP_AUTHENTICATION_FACTORY## -->|${http_authentication_factory}|" $CONFIG_FILE
  sed -i "s|<!-- ##ELYTRON_SECURITY_DOMAIN## -->|${elytron_security_domain}|" $CONFIG_FILE
}
