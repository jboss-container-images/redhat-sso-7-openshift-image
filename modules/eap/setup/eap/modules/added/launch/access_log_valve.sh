#!/bin/sh

# Access Log Valve configuration script
# Usage:
#   it is disabled by default, to disable it set the following variable to true:
#   ENABLE_ACCESS_LOG
#
# Default pattern used across all products:
#   %h %l %u %t %{X-Forwarded-Host}i "%r" %s %b
#          eap7 %{i,X-Forwarded-Host}
#
# Where:
#   %h: Remote host name
#   %l: Remote logical username from identd (always returns '-')
#   %u: Remote user that was authenticated
#   %t: Date and time, in Common Log Format format
#   %{X-Forwarded-Host}: for X-Forwarded-Host incoming headers
#   %r: First line of the request, generally something like this: "GET /index.jsf HTTP/1.1"
#   %s: HTTP status code of the response
#   %b: Bytes sent, excluding HTTP headers, or '-' if no bytes were sent
#
# Example of configuration that will be added on standalone-openshift.xml for eap6
#   <valve name="accessLog" module="org.jboss.openshift" class-name="org.jboss.openshift.valves.StdoutAccessLogValve">
#       <param param-name="pattern" param-value="%h %l %u %t %{X-Forwarded-Host}i "%r" %s %b" />
#   </valve>
#
# Example for eap7.x
#   <access-log use-server-log="true" pattern="%h %l %u %t %{i,X-Forwarded-Host} "%r" %s %b"/>
#
# This script will be executed during container startup

source $JBOSS_HOME/bin/launch/logging.sh

function configure() {
  configure_access_log_valve
  configure_access_log_handler
}

function configure_access_log_valve() {

  local mode
  getConfigurationMode "<!-- ##ACCESS_LOG_VALVE## -->" "mode"

  if [ "${ENABLE_ACCESS_LOG^^}" == "TRUE" ]; then
    log_info "Configuring Access Log Valve."
    if [ "${mode}" == "xml" ]; then
      local pattern=$(getPattern "add-xml")
      local valve="<access-log use-server-log=\"true\" pattern=\"${pattern}\"/>"
      sed -i "s|<!-- ##ACCESS_LOG_VALVE## -->|${valve}|" $CONFIG_FILE
    else
            # A lot of XPath here since we need to do more advanced stuff than CLI allows us to...

      # Check there is an Undertow subsystem
      local subsystemRet
      local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:undertow:')]\""
      testXpathExpression "${xpath}" "subsystemRet"
      if [ "${subsystemRet}" -ne 0 ]; then
        echo "You have set ENABLE_ACCESS_LOG=true to add the access-log valve. Fix your configuration to contain the undertow subsystem for this to happen." >> ${CONFIG_ERROR_FILE}
        return
      fi

      # Not having any servers is an error
      local serverNamesRet
      # We grab the <server name="..."> attributes, and will use them later
      local serverNames
      local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:undertow:')]/*[local-name()='server']/@name\""
      testXpathExpression "${xpath}" "serverNamesRet" "serverNames"
      if [ "${serverNamesRet}" -ne 0 ]; then
        echo "You have set ENABLE_ACCESS_LOG=true to add the access-log valve. Fix your configuration to contain at least one server in the undertow subsystem for this to happen." >> ${CONFIG_ERROR_FILE}
        return
      fi

      # Not having any server hosts is an error
      local hostsRet
      local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:undertow:')]/*[local-name()='server']/*[local-name()='host']\""
      testXpathExpression "${xpath}" "hostsRet"
      if [ "${hostsRet}" -ne 0 ]; then
        echo "You have set ENABLE_ACCESS_LOG=true to add the access-log valve. Fix your configuration to contain at least one server with one host in the undertow subsystem for this to happen." >> ${CONFIG_ERROR_FILE}
        return
      fi

      serverNames=$(splitAttributesStringIntoLines "${serverNames}" "name")
      while read -r serverName; do
        add_cli_commands_for_server_hosts "${serverName}"
      done <<< "${serverNames}"
    fi
  else
      log_info "Access log is disabled, ignoring configuration."
  fi
}

function add_cli_commands_for_server_hosts() {
  local serverName=$1

  local ret
  local hostNames
  local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:undertow:')]/*[local-name()='server' and @name='${serverName}']/*[local-name()='host']/@name\""
  testXpathExpression "${xpath}" "ret" "hostNames"
  if [ "${ret}" -ne 0 ]; then
    echo "You have set ENABLE_ACCESS_LOG=true to add the access-log valve. This is not added to the undertow server '${serverName}' since it has no hosts." >> ${CONFIG_WARNING_FILE}
    return
  fi

  hostNames=$(splitAttributesStringIntoLines "${hostNames}" "name")
  while read -r hostName; do
    add_cli_commands_for_host "${serverName}" "${hostName}"
  done <<< "${hostNames}"

}

function add_cli_commands_for_host() {
  local serverName=$1
  local hostName=$2

  local alRet
  local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:undertow:')]/*[local-name()='server' and @name='${serverName}']/*[local-name()='host' and @name='${hostName}']/*[local-name()='access-log']\""
  testXpathExpression "${xpath}" "alRet"

  local cli
  local resourceAddr="/subsystem=undertow/server=${serverName}/host=${hostName}/setting=access-log"
  if [ "${alRet}" -eq 0 ]; then
    # There is already an access log defined. Check it has the same values and give an error if not
    # We tried doing this in CLI but there seems to be a problem checking/comparing return values when
    # the value contains a string which is the case for the 'pattern' attribute

    # Check use-server-log with CLI since it works
    cli="
      if (result.use-server-log != true) of ${resourceAddr}:query(select=[\"pattern\", \"use-server-log\"])
        echo You have set ENABLE_ACCESS_LOG=true to add the access-log valve. However there is already one for ${resourceAddr} which has conflicting values. Fix your configuration. >> \${error_file}
        exit
      end-if
    "
    # Check pattern with XPath since it contains spaces and won't in CLI
    local pathRet
    local xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:undertow:')]/*[local-name()='server' and @name='${serverName}']/*[local-name()='host' and @name='${hostName}']/*[local-name()='access-log']/@pattern\""
    local existingPattern
    testXpathExpression "${xpath}" "pathRet" "existingPattern"
    local nonMatching
    if [ "${pathRet}" -eq 0 ]; then
      existingPattern=$(splitAttributesStringIntoLines "${existingPattern}" "pattern")
      local pattern=$(getPattern "read-xml")
      while read -r value; do
        if [ "${value}" != "${pattern}" ]; then
          nonMatching="1"
        fi
      done <<< "${existingPattern}"
    else
      nonMatching="1"
    fi

    if [ "${nonMatching}" == "1" ]; then
      echo "You have set ENABLE_ACCESS_LOG=true to add the access-log valve. However there is already one for ${resourceAddr} which has conflicting values. Fix your configuration." >> ${CONFIG_ERROR_FILE}
      return
    fi
  else
    # There is no access log defined. Add it
    local pattern=$(getPattern "add-cli")
    cli="
      ${resourceAddr}:add(pattern=\"${pattern}\", use-server-log=true)
    "
  fi

  echo "$cli" >> ${CLI_SCRIPT_FILE}
}


function version_compare () {
    [ "$1" = "`echo -e \"$1\n$2\" | sort -V | head -n1`" ] && echo "older" || echo "newer"
}

function configure_access_log_handler() {

  if [ "${ENABLE_ACCESS_LOG^^}" == "TRUE" ]; then
    IS_NEWER_OR_EQUAL_TO_7_2=$(version_compare "$JBOSS_DATAGRID_VERSION" "7.2")

    local log_category="org.infinispan.rest.logging.RestAccessLoggingHandler"

    # In this piece we check whether this is JDG and whether the version is >= 7.2
    if [ ! -z $JBOSS_DATAGRID_VERSION ] && [ $IS_NEWER_OR_EQUAL_TO_7_2 = "newer" ]; then
      log_category="org.infinispan.REST_ACCESS_LOG"
    fi

    local mode
    getConfigurationMode "<!-- ##ACCESS_LOG_HANDLER## -->" "mode"

    if [ "${mode}" = "xml" ]; then
      sed -i "s|<!-- ##ACCESS_LOG_HANDLER## -->|<logger category=\"${log_category}\"><level name=\"TRACE\"/></logger>|" $CONFIG_FILE
    elif [ "${mode}" = "cli" ]; then

      if [ -z "${ENABLE_ACCESS_LOG_TRACE}" ] || [ "${ENABLE_ACCESS_LOG_TRACE^^}" != "TRUE" ]; then
        # The EAP configuration did not contain an ##ACCESS_LOG_HANDLER## marker. So it looks like
        # this is for some layered products. Also since it is a TRACE level warning perhaps the user
        # is meant to add the marker to get this trace logging. However, with the CLI alternative
        # this would have taken effect regardless.
        # So explicitly enable it by setting -e ENABLE_ACCESS_LOG_TRACE=true
        return
      fi

      subsystemAddr="/subsystem=logging"
      resourceAddr="${subsystemAddr}/logger=${log_category}"
      local cli="
        if (outcome != success) of ${subsystemAddr}:read-resource
          echo You have set ENABLE_ACCESS_LOG=true to add the access log logger category. Fix your configuration to contain the logging subsystem for this to happen. >> \${error_file}
        end-if

        if (outcome == success && (result.category != "${log_category}" || result.level != "TRACE")) of ${resourceAddr}:query(select=[\"category\", \"level\"])
          echo You have set ENABLE_ACCESS_LOG=true to add the access log logger category '${log_category}'. However one already exists which has conflicting values. Fix your configuration to contain the logging subsystem for this to happen. >> \${error_file}
        end-if

        if (outcome != success) of ${resourceAddr}:read-resource
          ${resourceAddr}:add(level=TRACE)
        end-if
      "
      echo "${cli}" >> ${CLI_SCRIPT_FILE}
    fi
  fi
}

function getPattern() {
  local mode="${1}"
  if [ "${mode}" = "add-xml" ]; then
    echo "%h %l %u %t %{i,X-Forwarded-Host} \&quot;%r\&quot; %s %b"
  elif [ "${mode}" = "read-xml" ]; then
    echo "%h %l %u %t %{i,X-Forwarded-Host} &quot;%r&quot; %s %b"
  elif [ "${mode}" = "add-cli" ]; then
    echo "%h %l %u %t %{i,X-Forwarded-Host} \\\"%r\\\" %s %b"
  fi
}
