#!/bin/bash

source $JBOSS_HOME/bin/launch/launch-common.sh

# RHSSO-2211 Import common RH-SSO global variables & functions
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

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
      # RHSSO-2017 Escape possible ampersand and semicolong characters
      # which are interpolated when used in sed righ-hand side expression
      mgmt_iface_replace_str=$(escape_sed_rhs_interpolated_characters "${mgmt_iface_replace_str}")
      # EOF RHSSO-2017 correction
      # CIAM-1394 correction
      sed -i "s${AUS}><!-- ##MGMT_IFACE_REALM## -->${AUS}${mgmt_iface_replace_str}${AUS}" "$CONFIG_FILE"
      # EOF CIAM-1394 correction
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
