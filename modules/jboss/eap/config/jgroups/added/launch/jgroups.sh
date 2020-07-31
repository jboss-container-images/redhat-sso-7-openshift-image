# only processes a single environment as the placeholder is not preserved

if [ -n "${LOGGING_INCLUDE}" ]; then
    source "${LOGGING_INCLUDE}"
else
    source $JBOSS_HOME/bin/launch/logging.sh
fi

# required shared elytron functions
if [ -n "${ELYTRON_INCLUDE}" ]; then
    source "${ELYTRON_INCLUDE}"
else
    source $JBOSS_HOME/bin/launch/elytron.sh
fi

prepareEnv() {
  unset JGROUPS_ENCRYPT_SECRET
  unset JGROUPS_ENCRYPT_PASSWORD
  unset JGROUPS_ENCRYPT_KEYSTORE_DIR
  unset JGROUPS_ENCRYPT_KEYSTORE
  unset JGROUPS_ENCRYPT_NAME
}

configure() {
  configure_jgroups_encryption
}

configureEnv() {
  configure
}

create_jgroups_elytron_encrypt_sym() {
    declare jg_encrypt_keystore="$1" jg_encrypt_key_alias="$2" jg_encrypt_password="$3"
    local encrypt="<encrypt-protocol type=\"SYM_ENCRYPT\" key-store=\"${jg_encrypt_keystore}\" key-alias=\"${jg_encrypt_key_alias}\">\
                       <key-credential-reference clear-text=\"${jg_encrypt_password}\"/>\
                   </encrypt-protocol>"
    echo ${encrypt}
}

create_jgroups_encrypt_asym() {
    # Asymmetric encryption using public/private encryption to fetch the shared secret key
    # from the docs: "The ASYM_ENCRYPT protocol should be configured immediately before the pbcast.NAKACK2"
    # this also *requires* AUTH to be enabled.
    # TODO: make these properties configurable, this is currently just falling back on defaults.
    declare sym_keylength="${1:-}" sym_algorithm="${2:-}" asym_keylength="${3:-}" asym_algorithm="${4:-}" change_key_on_leave="${5:-}"
    local jgroups_encrypt="\
                    <protocol type=\"ASYM_ENCRYPT\">\n\
                        <property name=\"sym_keylength\">${sym_keylength:-128}</property>\n\
                        <property name=\"sym_algorithm\">${sym_algorithm:-AES/ECB/PKCS5Padding}</property>\n\
                        <property name=\"asym_keylength\">${asym_keylength:-512}</property>\n\
                        <property name=\"asym_algorithm\">${asym_algorithm:-RSA}</property>\n\
                        <property name=\"change_key_on_leave\">${change_key_on_leave:-true}</property>\n\
                    </protocol>"
    echo ${jgroups_encrypt}
}

create_jgroups_elytron_legacy() {
    declare jg_encrypt_keystore="$1" jg_encrypt_password="$2" jg_encrypt_name="$3" jg_encrypt_keystore_dir="$4"
    # compatibility with old marker, only used if new marker is not present
    local legacy_encrypt="\
        <protocol type=\"SYM_ENCRYPT\">\
          <property name=\"provider\">SunJCE</property>\
          <property name=\"sym_algorithm\">AES</property>\
          <property name=\"encrypt_entire_message\">true</property>\
          <property name=\"keystore_name\">${jg_encrypt_keystore_dir}/${jg_encrypt_keystore}</property>\
          <property name=\"store_password\">${jg_encrypt_password}</property>\
          <property name=\"alias\">${jg_encrypt_name}</property>\
        </protocol>"
    echo ${legacy_encrypt}
}

validate_keystore() {
    declare jg_encrypt_secret="$1" jg_encrypt_name="$2" jg_encrypt_password="$3" jg_encrypt_keystore="$4"
    if [ -n "${jg_encrypt_secret}"   -a \
      -n "${jg_encrypt_name}"         -a \
      -n "${jg_encrypt_password}"     -a \
      -n "${jg_encrypt_keystore}" ]; then
        echo "valid"
      elif [ -n "${jg_encrypt_secret}" ]; then
        echo "partial"
      else
        echo "missing"
      fi
}

# for legacy configs, we require JGROUPS_ENCRYPT_KEYSTORE_DIR
validate_keystore_legacy() {
    declare jg_encrypt_secret="$1" jg_encrypt_name="$2" jg_encrypt_password="$3" jg_encrypt_keystore="$4" jg_encrypt_keystore_dir="$5"
    if [ -n "${jg_encrypt_secret}"   -a \
      -n "${jg_encrypt_name}"         -a \
      -n "${jg_encrypt_password}"     -a \
      -n "${jg_encrypt_keystore_dir}" -a \
      -n "${jg_encrypt_keystore}" ]; then
        echo "valid"
      elif [ -n "${jg_encrypt_secret}" ]; then
        echo "partial"
      else
        echo "missing"
      fi
}

configure_jgroups_encryption() {
 local jgroups_encrypt_protocol="${JGROUPS_ENCRYPT_PROTOCOL:=SYM_ENCRYPT}"
 local jgroups_encrypt=""
 local key_store=""
 case "${jgroups_encrypt_protocol}" in
  "SYM_ENCRYPT")
    log_info "Configuring JGroups cluster traffic encryption protocol to SYM_ENCRYPT."
    local jgroups_unencrypted_message="Detected <STATE> JGroups encryption configuration, the communication within the cluster WILL NOT be encrypted."
    local keystore_warning_message=""
    local has_elytron_tls_marker=$(has_elytron_tls "${CONFIG_FILE}")
    local keystore_validation_state="";
    if [ "${has_elytron_tls_marker}" = "true" ]; then
        keystore_validation_state=$(validate_keystore "${JGROUPS_ENCRYPT_SECRET}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_KEYSTORE}")
    else
        keystore_validation_state=$(validate_keystore_legacy "${JGROUPS_ENCRYPT_SECRET}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_KEYSTORE_DIR}")
    fi

    if [ "${keystore_validation_state}" = "valid" ]; then
        # first add the elytron key-store:
        if [ "${has_elytron_tls_marker}" = "true" ]; then
            key_store=$(create_elytron_keystore "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_KEYSTORE_TYPE}" "${JGROUPS_ENCRYPT_KEYSTORE_DIR}")
            jgroups_encrypt=$(create_jgroups_elytron_encrypt_sym "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_ENTIRE_MESSAGE:-true}")
        else
            # compatibility with old marker, only used if new marker is not present
            jgroups_encrypt=$(create_jgroups_elytron_legacy "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_KEYSTORE_DIR}")
        fi
    elif [ "${keystore_validation_state}" = "partial" ]; then
        keystore_warning_message="${jgroups_unencrypted_message//<STATE>/partial}"
    else
         keystore_warning_message="${jgroups_unencrypted_message//<STATE>/missing}"
    fi

    if [ -n "${keystore_warning_message}" ]; then
        log_warning "${keystore_warning_message}"
    fi
  ;;
  "ASYM_ENCRYPT")
      log_info "Configuring JGroups cluster traffic encryption protocol to ASYM_ENCRYPT."
      if [ -n "${JGROUPS_ENCRYPT_SECRET}"      -o \
           -n "${JGROUPS_ENCRYPT_NAME}"         -o \
           -n "${JGROUPS_ENCRYPT_PASSWORD}"     -o \
           -n "${JGROUPS_ENCRYPT_KEYSTORE_DIR}" -o \
           -n "${JGROUPS_ENCRYPT_KEYSTORE}" ] ; then
        log_warning "The specified JGroups configuration properties (JGROUPS_ENCRYPT_SECRET, JGROUPS_ENCRYPT_NAME, JGROUPS_ENCRYPT_PASSWORD, JGROUPS_ENCRYPT_KEYSTORE_DIR JGROUPS_ENCRYPT_KEYSTORE) will be ignored when using JGROUPS_ENCRYPT_PROTOCOL=ASYM_ENCRYPT. Only JGROUPS_CLUSTER_PASSWORD is used."
      fi

      # CLOUD-2437 AUTH protocol is required when using ASYM_ENCRYPT protocol: https://github.com/belaban/JGroups/blob/master/conf/asym-encrypt.xml#L23
      if [ -n "${JGROUPS_CLUSTER_PASSWORD}" ]; then
        jgroups_encrypt=$(create_jgroups_encrypt_asym)
      else
        log_warning "JGROUPS_ENCRYPT_PROTOCOL=ASYM_ENCRYPT requires JGROUPS_CLUSTER_PASSWORD to be set and not empty, the communication within the cluster WILL NOT be encrypted."
      fi
    ;;
  esac


  if [ "$(has_elytron_tls "${CONFIG_FILE}")" = "true" ] || [ "$(has_elytron_keystore "${CONFIG_FILE}")" = "true" ]; then
    # insert the new config element, only if it hasn't been added already
    insert_elytron_tls_config_if_needed "${CONFIG_FILE}"
    # note we leave the <!-- ##ELYTRON_KEY_STORE## --> tag in case something else needs to add a keystore etc.
    sed -i "s|<!-- ##ELYTRON_KEY_STORE## -->|${key_store}<!-- ##ELYTRON_KEY_STORE## -->|" $CONFIG_FILE
  fi

  # this will either substitute in the new config, or the legacy one, depending on how we were configured above.
  sed -i "s|<!-- ##JGROUPS_ENCRYPT## -->|${jgroups_encrypt}|g" "$CONFIG_FILE"

}
