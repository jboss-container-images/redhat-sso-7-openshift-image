#!/bin/sh
source $JBOSS_HOME/bin/launch/logging.sh

function prepareEnv() {
  unset ADMIN_PASSWORD
  unset ADMIN_USERNAME
  unset EAP_ADMIN_PASSWORD
  unset EAP_ADMIN_USERNAME
}

function configure() {
  configure_administration
}

function configureEnv() {
  configure
}

function configure_administration() {
  local mode
    getConfigurationMode "<!-- ##MGMT_IFACE_REALM## -->" "mode"
  if [ -n "${ADMIN_USERNAME}" -a -n "$ADMIN_PASSWORD" ]; then
    # The following fails as-is since there is no $JBOSS_HOME/domain/configuration folder
    #   $JBOSS_HOME/bin/add-user.sh -u "$ADMIN_USERNAME" -p "$ADMIN_PASSWORD"
    # If we just specify -sc it will do jut the $JBOSS_HOME/standalone/configuration files
    $JBOSS_HOME/bin/add-user.sh -u "$ADMIN_USERNAME" -p "$ADMIN_PASSWORD" -sc $JBOSS_HOME/standalone/configuration

    if [ "$?" -ne "0" ]; then
        log_error "Failed to create the management realm user $ADMIN_USERNAME"
        log_error "Exiting..."
        exit
    fi

    if [ "${mode}" = "xml" ]; then
      local mgmt_iface_replace_str="security-realm=\"ManagementRealm\""
      sed -i "s|><!-- ##MGMT_IFACE_REALM## -->| ${mgmt_iface_replace_str}>|" "$CONFIG_FILE"
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
  else
    # required by probe, server must start unsecured if no admin user set.
    if [ "${mode}" = "cli" ]; then
      cat << EOF >> "${CLI_SCRIPT_FILE}"
        if (outcome == success && result != undefined) of /core-service=management/management-interface=http-interface:read-attribute(name=http-authentication-factory)
          /core-service=management/management-interface=http-interface:write-attribute(name=http-authentication-factory)
        end-if
EOF
    fi
  fi
}
