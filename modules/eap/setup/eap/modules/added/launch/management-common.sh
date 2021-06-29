#!/bin/bash

source $JBOSS_HOME/bin/launch/launch-common.sh

# Arguments:
# $1 - realm
function add_management_interface_realm() {
    local mgmt_iface_realm="${1}"
    local mgmt_iface_replace_str
    local mode
    getConfigurationMode "<!-- ##MGMT_IFACE_REALM## -->" "mode"
    if [ "x${mgmt_iface_realm}" == "x" ]; then
      mgmt_iface_realm=ManagementRealm
    fi

    if [ "${mode}" = "xml" ]; then
      mgmt_iface_replace_str=" security-realm=\"$mgmt_iface_realm\">"
      sed -i "s|><!-- ##MGMT_IFACE_REALM## -->|${mgmt_iface_replace_str}|" "$CONFIG_FILE"
    elif [ "${mode}" = "cli" ]; then
      cat << EOF >> "${CLI_SCRIPT_FILE}"
      if (outcome != success) of /core-service=management/management-interface=http-interface:read-resource
        echo Adding security realm to management http-interface error. Fix your configuration to contain the http-interface for this to happen. >> \${error_file}
        exit
      end-if
      /core-service=management/management-interface=http-interface:write-attribute(name=security-realm, value=$mgmt_iface_realm)
EOF
    fi
}
