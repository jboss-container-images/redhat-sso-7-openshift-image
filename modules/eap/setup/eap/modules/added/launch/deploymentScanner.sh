#!/bin/sh

function configure() {
  configure_deployment_scanner
}

function configure_deployment_scanner() {
  local auto_deploy_exploded
  local explicitly_set=false
  if [[ -n "$JAVA_OPTS_APPEND" ]] && [[ $JAVA_OPTS_APPEND == *"Xdebug"* ]]; then
    sed -i "s|##AUTO_DEPLOY_EXPLODED##|true|" "$CONFIG_FILE"
    auto_deploy_exploded=true
  elif [ -n "$AUTO_DEPLOY_EXPLODED" ] || [ -n "$OPENSHIFT_AUTO_DEPLOY_EXPLODED" ]; then
    auto_deploy_exploded="${AUTO_DEPLOY_EXPLODED:-${OPENSHIFT_AUTO_DEPLOY_EXPLODED}}"
    auto_deploy_exploded=${auto_deploy_exploded,,}
    explicitly_set=true
  else
    auto_deploy_exploded="false"
  fi

  local configure_mode=""
  getConfigurationMode "##AUTO_DEPLOY_EXPLODED##" "configure_mode"

  if [ "${configure_mode}" = "xml" ]; then
    sed -i "s|##AUTO_DEPLOY_EXPLODED##|${auto_deploy_exploded}|" "$CONFIG_FILE"
  elif [ "${configure_mode}" = "cli" ] && [ "${explicitly_set}" = "true" ]; then
    # We only do this if the variable was explicitly set. Otherwise we assume the user has provided their own configuration

    # No deployement-scanner subsystem is an error (do this here rather than in CLI because we are doing another check)
    local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:deployment-scanner:')]\""
    local ssRet
    testXpathExpression "${xpath}" "ssRet"
    if [ "${ssRet}" -ne 0 ]; then
      echo "You have set environment variables to set auto-deploy-exploded for the deployment scanner. Fix your configuration to contain the deployment-scanner subsystem for this to happen." >> "${CONFIG_ERROR_FILE}"
      return
    fi

    # Not having any scanners is an error
    local scannersRet
    local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:deployment-scanner:')]/*[local-name()='deployment-scanner']\""
    testXpathExpression "${xpath}" "scannersRet"
    if [ "${scannersRet}" -ne 0 ]; then
      echo "You have set environment variables to set auto-deploy-exploded for the deployment scanner. Fix your configuration to contain at least one deployment-scanner in the deployment-scanner subsystem for this to happen." >> ${CONFIG_ERROR_FILE}
      return
    fi

    local cli_command="
    for scannerName in /subsystem=deployment-scanner:read-children-names(child-type=scanner)
      if (result != undefined && result != ${auto_deploy_exploded}) of /subsystem=deployment-scanner/scanner=\$scannerName:read-attribute(name=auto-deploy-exploded, include-defaults=false)
        echo You have set environment variables to set auto-deploy-exploded for the deployment scanner but your configuration already contains a conflicting value. Fix your configuration. >> \${error_file}
        exit
      else
        /subsystem=deployment-scanner/scanner=\$scannerName:write-attribute(name=auto-deploy-exploded, value=${auto_deploy_exploded})
      end-if
    done"
    echo "${cli_command}" >> "${CLI_SCRIPT_FILE}"
  fi
}

