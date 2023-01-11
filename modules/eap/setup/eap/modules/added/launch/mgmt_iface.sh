#!/bin/bash
# shellcheck disable=SC1091
source "${JBOSS_HOME}"/bin/launch/logging.sh

function configure() {
  configure_mgmt_iface
}

function configureEnv() {
  configure
}

function configure_mgmt_iface() {
  # Determine the configuration mode
  local mode
  # Note: From it's definition the getConfigurationMode() routine stores
  #       the type of currently used configuration mode into the 2nd
  #       parameter of the function call, instead of returning it. Therefore:
  #
  # 1) We can't simply assign its return value to the local 'mode' env var in one line,
  # 2) But instead of that we pass the local 'mode' env var as 2nd arg to the function
  getConfigurationMode "<!-- ##MGMT_IFACE_REALM## -->" "mode"
  # Moreover, the code below covers solely the cases, where mode is either 'xml' or 'cli'
  # Thus any other 'mode' value setting (other than 'cli' or 'xml') is an error
  if [ "${mode}" != "xml" ] && [ "${mode}" != "cli" ]; then
    local -a invalid_mode_errmsg=(
      "Invalid configuration mode: '${mode}' detected."
      "Only 'cli' and 'xml' modes are supported."
    )
    log_error "$(printf '%s' "${invalid_mode_errmsg[*]}")"
    exit 1
  # Based on the mode configure the management interface
  elif [ "${mode}" = "xml" ]; then
    local mgmt_iface_replace_str="security-realm=\"ManagementRealm\""
    # CIAM-1394 correction
    sed -i "s${AUS}><!-- ##MGMT_IFACE_REALM## -->${AUS} ${mgmt_iface_replace_str}>${AUS}" "$CONFIG_FILE"
    # EOF CIAM-1394 correction
  elif [ "${mode}" = "cli" ]; then
    cat << EOF >> "${CLI_SCRIPT_FILE}"
    if (outcome != success) of /core-service=management/management-interface=http-interface:read-resource
      echo You have set environment variables to configure http-interface security-realm. Fix your configuration to contain the http-interface for this to happen. >> \${error_file}
      exit
    end-if
    if (result == undefined) of /core-service=management/management-interface=http-interface:read-attribute(name=http-authentication-factory)
      /core-service=management/management-interface=http-interface:write-attribute(name=security-realm, value=ManagementRealm)
    end-if
EOF
  fi
}
