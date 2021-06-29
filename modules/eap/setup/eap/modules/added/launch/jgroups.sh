#!/bin/sh

source $JBOSS_HOME/bin/launch/jgroups_common.sh

preConfigure() {
  init_protocol_list_store
}

prepareEnv() {
  unset JGROUPS_ENCRYPT_SECRET
  unset JGROUPS_ENCRYPT_PASSWORD
  unset JGROUPS_ENCRYPT_KEYSTORE_DIR
  unset JGROUPS_ENCRYPT_KEYSTORE
  unset JGROUPS_ENCRYPT_NAME
}

configure() {
  xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:jgroups:')]\""
  local ret_jgroups
  testXpathExpression "${xpath}" "ret_jgroups"
  if [ "${ret_jgroups}" -eq 0 ]; then
    configure_jgroups_encryption
  else
    log_info "Clustering feature is not enabled, no jgroups subsystem present in server configuration."
  fi
}

configureEnv() {
  configure
}

create_jgroups_elytron_encrypt() {
    declare jg_encrypt_protocol="${1}" jg_encrypt_keystore="${2}" jg_encrypt_key_alias="${3}" jg_encrypt_password="${4}"
    local encrypt

    read -r -d '' encrypt <<- EOF
    <encrypt-protocol type="${jg_encrypt_protocol}" key-store="${jg_encrypt_keystore}" key-alias="${jg_encrypt_key_alias}">
       <key-credential-reference clear-text="${jg_encrypt_password}"/>
    </encrypt-protocol>

EOF

    echo "${encrypt}"
}

create_jgroups_elytron_encrypt_cli() {
  declare jg_encrypt_protocol="${1}" jg_encrypt_keystore="${2}" jg_encrypt_key_alias="${3}" jg_encrypt_password="${4}"

  local protocolTypes
  local xpath
  local result
  local index
  local protocolType
  local config
  local missingNAKACK2="false"

    xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:jgroups:')]//*[local-name()='stack']/@name\""
    local stackNames
    testXpathExpression "${xpath}" "result" "stackNames"

    if [ ${result} -ne 0 ]; then
      echo "You have set JGROUPS_CLUSTER_PASSWORD environment variable to configure ${jg_encrypt_protocol} protocol but your configuration does not contain any stacks in the JGroups subsystem. Fix your configuration." >> "${CONFIG_ERROR_FILE}"
      return
    else
      stackNames=$(splitAttributesStringIntoLines "${stackNames}" "name")
      while read -r stack; do
        index=$(get_protocol_position "${stack}" "pbcast.NAKACK2")
        if [ ${index} -eq -1 ]; then
          echo "You have set JGROUPS_CLUSTER_PASSWORD environment variable to configure ${jg_encrypt_protocol} protocol but pbcast.NAKACK2 protocol was not found for ${stack^^} stack. Fix your configuration to contain the pbcast.NAKACK2 in the JGroups subsystem for this to happen." >> "${CONFIG_ERROR_FILE}"
          missingNAKACK2="true"
          continue
        fi
        op=("/subsystem=jgroups/stack=$stack/protocol=${jg_encrypt_protocol}:add(add-index=${index}, key-store=\"${jg_encrypt_keystore}\", key-alias=\"${jg_encrypt_key_alias}\", key-credential-reference={clear-text=\"${jg_encrypt_password}\"})")
        config="${config} $(configure_protocol_cli_helper "${stack}" "${jg_encrypt_protocol}" "${op[@]}")"
        add_protocol_at_prosition "${stack}" "${jg_encrypt_protocol}" ${index}
      done <<< "${stackNames}"
    fi

  if [ "${missingNAKACK2}" = "false" ]; then
    echo "${config}"
  fi
}

create_jgroups_encrypt_asym() {
    # Asymmetric encryption using public/private encryption to fetch the shared secret key
    # from the docs: "The ASYM_ENCRYPT protocol should be configured immediately before the pbcast.NAKACK2"
    # this also *requires* AUTH to be enabled.
    # TODO: make these properties configurable, this is currently just falling back on defaults.
    declare sym_keylength="${1:-}" sym_algorithm="${2:-}" asym_keylength="${3:-}" asym_algorithm="${4:-}" change_key_on_leave="${5:-}"
    local jgroups_encrypt
    read -r -d '' jgroups_encrypt <<- EOF
      <protocol type="ASYM_ENCRYPT">
          <property name="sym_keylength">${sym_keylength:-128}</property>
          <property name="sym_algorithm">${sym_algorithm:-AES/ECB/PKCS5Padding}</property>
          <property name="asym_keylength">${asym_keylength:-512}</property>
          <property name="asym_algorithm">${asym_algorithm:-RSA}</property>
          <property name="change_key_on_leave">${change_key_on_leave:-true}</property>
      </protocol>
EOF
    echo "${jgroups_encrypt}"
}

create_jgroups_encrypt_asym_cli() {
    declare sym_keylength="${1:-}" sym_algorithm="${2:-}" asym_keylength="${3:-}" asym_algorithm="${4:-}" change_key_on_leave="${5:-}"

    local protocolTypes
    local xpath
    local result
    local index
    local protocolType
    local config
    local missingNAKACK2="false"

    xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:jgroups:')]//*[local-name()='stack']/@name\""
    local stackNames
    testXpathExpression "${xpath}" "result" "stackNames"

    if [ ${result} -ne 0 ]; then
      echo "You have set JGROUPS_CLUSTER_PASSWORD environment variable to configure ASYM_ENCRYPT protocol but your configuration does not contain any stacks in the JGroups subsystem. Fix your configuration." >> "${CONFIG_ERROR_FILE}"
      return
    else
      stackNames=$(splitAttributesStringIntoLines "${stackNames}" "name")
      while read -r stack; do
        index=$(get_protocol_position "${stack}" "pbcast.NAKACK2")
        if [ ${index} -eq -1 ]; then
            echo "You have set JGROUPS_CLUSTER_PASSWORD environment variable to configure ASYM_ENCRYPT protocol but pbcast.NAKACK2 protocol was not found for ${stack^^} stack. Fix your configuration to contain the pbcast.NAKACK2 in the JGroups subsystem for this to happen." >> "${CONFIG_ERROR_FILE}"
            missingNAKACK2="true"
            continue
        fi
        op=("/subsystem=jgroups/stack=$stack/protocol=ASYM_ENCRYPT:add(add-index=${index})"
            "/subsystem=jgroups/stack=$stack/protocol=ASYM_ENCRYPT/property=sym_keylength:add(value=\"${sym_keylength:-128}\")"
            "/subsystem=jgroups/stack=$stack/protocol=ASYM_ENCRYPT/property=sym_algorithm:add(value=\"${sym_algorithm:-AES/ECB/PKCS5Padding}\")"
            "/subsystem=jgroups/stack=$stack/protocol=ASYM_ENCRYPT/property=asym_keylength:add(value=\"${asym_keylength:-512}\")"
            "/subsystem=jgroups/stack=$stack/protocol=ASYM_ENCRYPT/property=asym_algorithm:add(value=\"${asym_algorithm:-RSA}\")"
            "/subsystem=jgroups/stack=$stack/protocol=ASYM_ENCRYPT/property=change_key_on_leave:add(value=\"${change_key_on_leave:-true}\")"
        )
        config="${config} $(configure_protocol_cli_helper "${stack}" "ASYM_ENCRYPT" "${op[@]}")"
        add_protocol_at_prosition "${stack}" "ASYM_ENCRYPT" ${index}
      done  <<< "${stackNames}"
    fi

    if [ "${missingNAKACK2}" = "false" ]; then
      echo "${config}"
    fi
}

create_jgroups_elytron_legacy() {
    declare jg_encrypt_keystore="$1" jg_encrypt_password="$2" jg_encrypt_name="$3" jg_encrypt_keystore_dir="$4"
    # compatibility with old marker, only used if new marker is not present
    local legacy_encrypt
    read -r -d '' legacy_encrypt <<- EOF
      <protocol type="SYM_ENCRYPT">
        <property name="provider">SunJCE</property>
        <property name="sym_algorithm">AES</property>
        <property name="encrypt_entire_message">true</property>
        <property name="keystore_name">${jg_encrypt_keystore_dir}/${jg_encrypt_keystore}</property>
        <property name="store_password">${jg_encrypt_password}</property>
        <property name="alias">${jg_encrypt_name}</property>
      </protocol>
EOF

    echo "${legacy_encrypt}"
}

create_jgroups_elytron_legacy_cli() {
  declare jg_encrypt_keystore="$1" jg_encrypt_password="$2" jg_encrypt_name="$3" jg_encrypt_keystore_dir="$4"

  local protocolTypes
  local xpath
  local result
  local index
  local protocolType
  local config
  local missingNAKACK2="false"

  xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:jgroups:')]//*[local-name()='stack']/@name\""
  local stackNames
  testXpathExpression "${xpath}" "result" "stackNames"

  if [ ${result} -ne 0 ]; then
    echo "You have set JGROUPS_CLUSTER_PASSWORD environment variable to configure SYM_ENCRYPT protocol but your configuration does not contain any stacks in the JGroups subsystem. Fix your configuration." >> "${CONFIG_ERROR_FILE}"
    return
  else
    stackNames=$(splitAttributesStringIntoLines "${stackNames}" "name")
    while read -r stack; do
      index=$(get_protocol_position "${stack}" "pbcast.NAKACK2")
      if [ ${index} -eq -1 ]; then
        echo "You have set JGROUPS_CLUSTER_PASSWORD environment variable to configure SYM_ENCRYPT protocol but pbcast.NAKACK2 protocol was not found for ${stack^^} stack. Fix your configuration to contain the pbcast.NAKACK2 in the JGroups subsystem for this to happen." >> "${CONFIG_ERROR_FILE}"
        missingNAKACK2="true"
        continue
      fi
      op=("/subsystem=jgroups/stack=$stack/protocol=SYM_ENCRYPT:add(add-index=${index})"
          "/subsystem=jgroups/stack=$stack/protocol=SYM_ENCRYPT/property=provider:add(value=SunJCE)"
          "/subsystem=jgroups/stack=$stack/protocol=SYM_ENCRYPT/property=sym_algorithm:add(value=AES)"
          "/subsystem=jgroups/stack=$stack/protocol=SYM_ENCRYPT/property=encrypt_entire_message:add(value=true)"
          "/subsystem=jgroups/stack=$stack/protocol=SYM_ENCRYPT/property=keystore_name:add(value=\"${jg_encrypt_keystore_dir}/${jg_encrypt_keystore}\")"
          "/subsystem=jgroups/stack=$stack/protocol=SYM_ENCRYPT/property=store_password:add(value=\"${jg_encrypt_password}\")"
          "/subsystem=jgroups/stack=$stack/protocol=SYM_ENCRYPT/property=alias:add(value=\"${jg_encrypt_name}\")"
        )
      config="${config} $(configure_protocol_cli_helper "${stack}" "SYM_ENCRYPT" "${op[@]}")"
      add_protocol_at_prosition "${stack}" "SYM_ENCRYPT" ${index}
    done <<< "${stackNames}"
  fi

  if [ "${missingNAKACK2}" = "false" ]; then
    echo "${config}"
  fi
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

validate_keystore_and_create() {
  local mode="${1}" protocol="${2}"

  valid_state=$(validate_keystore "${JGROUPS_ENCRYPT_SECRET}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_KEYSTORE}")

  if [ "${valid_state}" = "valid" ]; then
    if [ "${mode}" = "xml" ]; then
      key_store=$(create_elytron_keystore "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_KEYSTORE_TYPE}" "${JGROUPS_ENCRYPT_KEYSTORE_DIR}")
      jgroups_encrypt=$(create_jgroups_elytron_encrypt "${protocol}" "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_PASSWORD}")
    elif [ "${mode}" = "cli" ]; then
      key_store=$(create_elytron_keystore_cli "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_KEYSTORE_TYPE}" "${JGROUPS_ENCRYPT_KEYSTORE_DIR}")
      jgroups_encrypt=$(create_jgroups_elytron_encrypt_cli "${protocol}" "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_PASSWORD}")
    fi
  fi
}

# used when elytron marker is not present
validate_keystore_and_create_legacy() {
  declare mode="$1"

  valid_state=$(validate_keystore_legacy "${JGROUPS_ENCRYPT_SECRET}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_KEYSTORE_DIR}")

  if [ "${valid_state}" = "valid" ]; then
    if [ "${mode}" = "xml" ]; then
      jgroups_encrypt=$(create_jgroups_elytron_legacy "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_KEYSTORE_DIR}")
    elif [ "${mode}" = "cli" ]; then
      jgroups_encrypt=$(create_jgroups_elytron_legacy_cli "${JGROUPS_ENCRYPT_KEYSTORE}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_KEYSTORE_DIR}")
    fi
  fi
}

configure_jgroups_encryption() {
 local has_elytron_tls_marker=$(has_elytron_tls "${CONFIG_FILE}")
 local has_elytron_keystore_marker=$(has_elytron_keystore "${CONFIG_FILE}")

 if [ "${has_elytron_tls_marker}" = "true" ] || [ "${has_elytron_keystore_marker}" = "true" ]; then
   # insert the new config element, only if it hasn't been added already
   # basically it will transform the <!-- ##ELYTRON_TLS## --> into a divided sections separated by the following markers:
   # <!-- ##ELYTRON_KEY_STORE## --> <!-- ##ELYTRON_KEY_MANAGER## --> <!-- ##ELYTRON_SERVER_SSL_CONTEXT## -->
   # and will remove the old marker <!-- ##TLS## --> if exists.
   # It also takes care of not to add twice the <!-- ##ELYTRON_KEY_STORE## --> marker, if it is already there, then <!-- ##ELYTRON_TLS## -->
   # is not replaced.
   # This change will allow the configuration of the KeyStore used by JGroups via Elytron integration
   # instead of adding the keystore configuration at JGroups protocol level
   insert_elytron_tls_config_if_needed "${CONFIG_FILE}"
 fi

 local encrypt_conf_mode
 getConfigurationMode "<!-- ##JGROUPS_ENCRYPT## -->" "encrypt_conf_mode"

 local key_store_conf_mode
 getConfigurationMode "<!-- ##ELYTRON_KEY_STORE## -->" "key_store_conf_mode"

 local has_elytron_subsystem
 local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:wildfly:elytron:')]\""
 testXpathExpression "${xpath}" "has_elytron_subsystem"

 local jgroups_encrypt_protocol="${JGROUPS_ENCRYPT_PROTOCOL:=SYM_ENCRYPT}"
 local jgroups_encrypt=""
 local key_store=""
 local valid_state=""
 local jgroups_unencrypted_message=
 case "${jgroups_encrypt_protocol}" in
  "SYM_ENCRYPT")
    log_info "Configuring JGroups cluster traffic encryption protocol to SYM_ENCRYPT."
    jgroups_unencrypted_message="Detected <STATE> JGroups encryption configuration, the communication within the cluster WILL NOT be encrypted."

    if [ "${has_elytron_subsystem}" -eq 0 ]; then
      if [ "${key_store_conf_mode}" = "xml" ]; then
        validate_keystore_and_create "xml" "SYM_ENCRYPT"
      elif [ "${key_store_conf_mode}" = "cli" ]; then
        validate_keystore_and_create "cli" "SYM_ENCRYPT"

        # This if-check is here to cover the following case: User has strictly defined that he wants only replacement via xml markers (CONFIG_ADJUSTMENT_MODE=xml),
        # we have the Elytron subsystem but we do not have the Keystore marker, in that case, then replace the protocol using the "legacy" style,
        # which means include the key store in the JGroups protocol itself.
      elif [ "${CONFIG_ADJUSTMENT_MODE,,}" = "xml" ]; then
        validate_keystore_and_create_legacy "xml"
      fi
    else
      if [ "${key_store_conf_mode}" = "xml" ]; then
        validate_keystore_and_create_legacy "xml"
      elif [ "${key_store_conf_mode}" = "cli" ]; then
        validate_keystore_and_create_legacy "cli"
      fi
    fi

    if [ "${valid_state}" = "partial" ]; then
        log_warning "${jgroups_unencrypted_message//<STATE>/partial}"
    elif [ "${valid_state}" = "missing" ]; then
        log_warning "${jgroups_unencrypted_message//<STATE>/missing}"
    fi
  ;;
  "ASYM_ENCRYPT")
      log_info "Configuring JGroups cluster traffic encryption protocol to ASYM_ENCRYPT."

      # CLOUD-2437 AUTH protocol is required when using ASYM_ENCRYPT protocol
      if [ -n "${JGROUPS_CLUSTER_PASSWORD}" ]; then
        # Test if we have all the information available to configure ASYM_ENCRYPT protocol configuring the Key Store in the Elytron subsystem
        valid_state=$(validate_keystore "${JGROUPS_ENCRYPT_SECRET}" "${JGROUPS_ENCRYPT_NAME}" "${JGROUPS_ENCRYPT_PASSWORD}" "${JGROUPS_ENCRYPT_KEYSTORE}")

        if [ "${has_elytron_subsystem}" -eq 0 ] && [ "${valid_state}" = "valid" ]; then
          log_info "Detected valid JGroups encryption configuration, the communication within the cluster will be encrypted using ASYM_ENCRYPT and Elytron keystore."
          if [ "${key_store_conf_mode}" = "xml" ]; then
            validate_keystore_and_create "xml" "ASYM_ENCRYPT"
          elif [ "${key_store_conf_mode}" = "cli" ]; then
            validate_keystore_and_create "cli" "ASYM_ENCRYPT"
          fi
        else
          jgroups_unencrypted_message="Detected <STATE> JGroups encryption configuration, the communication within the cluster will be encrypted using a deprecated version of ASYM_ENCRYPT protocol. You need to set all of these variables to configure ASYM_ENCRYPT using the Elytron keystore: JGROUPS_ENCRYPT_SECRET, JGROUPS_ENCRYPT_NAME, JGROUPS_ENCRYPT_PASSWORD, JGROUPS_ENCRYPT_KEYSTORE."
          if [ ! "${has_elytron_subsystem}" -eq 0 ]; then
            log_warning "Elytron subsystem is not in your configuration, the communication within the cluster will be encrypted using a deprecated version of ASYM_ENCRYPT protocol."
          elif [ -n "${JGROUPS_ENCRYPT_SECRET}" ] || [ -n "${JGROUPS_ENCRYPT_NAME}" ] || [ -n "${JGROUPS_ENCRYPT_PASSWORD}" ] || [ -n "${JGROUPS_ENCRYPT_KEYSTORE}" ] || [ -n "${JGROUPS_ENCRYPT_KEYSTORE_DIR}" ]; then
            log_warning "${jgroups_unencrypted_message//<STATE>/partial}"
          else
            log_warning "${jgroups_unencrypted_message//<STATE>/missing}"
          fi

          if [ "${encrypt_conf_mode}" = "xml" ]; then
            jgroups_encrypt=$(create_jgroups_encrypt_asym)
          elif [ "${encrypt_conf_mode}" = "cli" ]; then
            jgroups_encrypt=$(create_jgroups_encrypt_asym_cli)
          fi
        fi
      else
        log_warning "JGROUPS_ENCRYPT_PROTOCOL=ASYM_ENCRYPT requires JGROUPS_CLUSTER_PASSWORD to be set and not empty, the communication within the cluster WILL NOT be encrypted."
      fi
    ;;
  esac

  if [ "${key_store_conf_mode}" = "xml" ]; then
    sed -i "s|<!-- ##ELYTRON_KEY_STORE## -->|${key_store}<!-- ##ELYTRON_KEY_STORE## -->|" $CONFIG_FILE
  elif [ "${key_store_conf_mode}" = "cli" ]; then
    echo "${key_store}" >> ${CLI_SCRIPT_FILE}
  fi

  if [ "${encrypt_conf_mode}" = "xml" ]; then
    sed -i "s|<!-- ##JGROUPS_ENCRYPT## -->|${jgroups_encrypt}|g" "$CONFIG_FILE"
  elif [ "${encrypt_conf_mode}" = "cli" ]; then
    echo "${jgroups_encrypt}" >> ${CLI_SCRIPT_FILE}
  fi
}


create_jgroups_encrypt_elytron_asym() {
  declare jg_encrypt_keystore="$1" jg_encrypt_key_alias="$2" jg_encrypt_password="$3" jg_encrypt_entire_message="$4"
  local encrypt
  read -r -d '' encrypt <<- EOF
  <encrypt-protocol type="ASYM_ENCRYPT" key-alias="${jg_encrypt_key_alias}" keystore="${jg_encrypt_keystore}">
    <key-credential-reference clear-text="${jg_encrypt_password}"/>
    <property name="encrypt_entire_message">"${jg_encrypt_entire_message}"</property>
  </encrypt-protocol>
EOF

  echo "${encrypt}"
}
