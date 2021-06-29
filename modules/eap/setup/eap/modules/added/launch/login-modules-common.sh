#!/bin/bash

source $JBOSS_HOME/bin/launch/launch-common.sh

# Arguments:
# $1 - code
# $2 - flag
# $3 - module
function configure_login_modules() {
    local login_module_code="${1}"
    local login_module_flag="${2}"
    local login_module_module="${3}"
    if [ "x${login_module_code}" != "x" ]; then
        if [ "x${login_module_flag}" = "x" ]; then
            login_module_flag="optional"
        fi
        local login_modules
        if [ "x${login_module_module}" != "x" ]; then
            login_modules="<login-module code=\"$login_module_code\" flag=\"$login_module_flag\" module=\"$login_module_module\"/>"
        else
            login_modules="<login-module code=\"$login_module_code\" flag=\"$login_module_flag\"/>"
        fi
        local confMode
        getConfigurationMode "<!-- ##OTHER_LOGIN_MODULES## -->" "confMode"

        if [ "${confMode}" = "xml" ]; then
          sed -i "s|<!-- ##OTHER_LOGIN_MODULES## -->|${login_modules}<!-- ##OTHER_LOGIN_MODULES## -->|" "$CONFIG_FILE"
        elif [ "${confMode}" = "cli" ]; then
          configure_login_module_cli "${login_module_code}" "${login_module_flag}" "${login_module_module}"
        fi
    fi
}

configure_login_module_cli() {
    sec_subsystem="/subsystem=security"
    sec_domain="${sec_subsystem}/security-domain=other"
    sec_domain_auth="${sec_domain}/authentication=classic"
    login_module="${sec_domain_auth}/login-module=$1"
    add_login_module="${login_module}:add(code=$1, flag=$2"
    if [ ! -z $3 ]; then
      add_login_module="$add_login_module, module=$3"
    fi
    add_login_module="$add_login_module)"
    cat << EOF >> ${CLI_SCRIPT_FILE}
        if (outcome != success) of $sec_subsystem:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the security subsystem. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome != success) of $sec_domain:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the other security domain. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome != success) of $sec_domain_auth:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the other security domain authentication configuration. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome == success) of $login_module:read-resource
          echo "You are adding the login module $1 to other security domain. However, your base configuration already contains it." >> \${error_file}
        else
          $add_login_module
        end-if
EOF
   
}
