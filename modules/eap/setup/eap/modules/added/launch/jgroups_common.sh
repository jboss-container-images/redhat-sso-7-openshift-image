#!/bin/sh
JGROUPS_PROTOCOL_ADDS="/tmp/jgroups-protocol-adds"

configure_protocol_cli_helper() {
  local params=("${@}")
  local stack=${params[0]}
  local protocol=${params[1]}
  local result
  IFS= read -rd '' result <<- EOF

    if (outcome == success) of /subsystem=jgroups/stack="${stack}"/protocol="${protocol}":read-resource
        echo Cannot configure jgroups '${protocol}' protocol under '${stack}' stack. This protocol is already configured. >> \${error_file}
        quit
    end-if

    if (outcome != success) of /subsystem=jgroups/stack="${stack}"/protocol="${protocol}":read-resource
        batch
EOF
  # removes the latest new line added by read builtin command
  result=$(echo -n "${result}")

  # starts in 2, since 0 and 1 are arguments
  for ((j=2; j<${#params[@]}; ++j)); do
    result="${result}
            ${params[j]}"
  done

  IFS= read -r -d '' result <<- EOF
        ${result}
       run-batch
    end-if
EOF


  echo "${result}"
}

# Initializes temporal files that keep the list of protocols for a specific stack from the
# configuration of JGroups subsystem reading it from the server config file
init_protocol_list_store() {
  rm -rf "${JGROUPS_PROTOCOL_ADDS}" 2>/dev/null
  mkdir "${JGROUPS_PROTOCOL_ADDS}"

  xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:jgroups:')]\""
  local ret_jgroups
  testXpathExpression "${xpath}" "ret_jgroups"
  if [ "${ret_jgroups}" -eq 0 ]; then
    xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:jgroups:')]//*[local-name()='stack']/@name\""
    local stackNames
    testXpathExpression "${xpath}" "result" "stackNames"
    if [ ${result} -eq 0 ]; then
      stackNames=$(splitAttributesStringIntoLines "${stackNames}" "name")
      while read -r stack; do
        echo -n "" > "${JGROUPS_PROTOCOL_ADDS}/${stack}_protocol_list"

        xpath="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:jgroups:')]//*[local-name()='stack' and @name='${stack}']/*[local-name()='protocol' or contains(local-name(), '-protocol')]/@type\""
        testXpathExpression "${xpath}" "result" "protocolTypes"
        if [ ${result} -eq 0 ]; then
          protocolTypes=$(splitAttributesStringIntoLines "${protocolTypes}" "type")
          echo "${protocolTypes}" >> "${JGROUPS_PROTOCOL_ADDS}/${stack}_protocol_list"
        fi
      done <<< "${stackNames}"
    fi
  fi
}

remove_protocol_list_store() {
  rm -rf "${JGROUPS_PROTOCOL_ADDS}" 2>/dev/null
}

get_protocols() {
  declare stack="${1}"
  if [ -s "${JGROUPS_PROTOCOL_ADDS}/${stack}_protocol_list" ]; then
    cat "${JGROUPS_PROTOCOL_ADDS}/${stack}_protocol_list"
  fi
}

add_protocol_at_prosition() {
  declare stack="${1}" protocol="${2}" index="${3}"

  local exist="false"
  local stack_list=()

  local _index=0
  while read -r line; do
    if [ "${protocol}" = "${line}" ]; then
      exist="true"
    fi
    if [ ${_index} -eq ${index} ]; then
      stack_list+=("${protocol}")
    fi
    stack_list+=("${line}")
    ((_index=$_index+1))
  done < "${JGROUPS_PROTOCOL_ADDS}/${stack}_protocol_list"

  if [ "${exist}" = "false" ]; then
    echo -n "" > "${JGROUPS_PROTOCOL_ADDS}/${stack}_protocol_list"

    for element in "${stack_list[@]}"; do
      echo "${element}" >> "${JGROUPS_PROTOCOL_ADDS}/${stack}_protocol_list"
    done
  fi
}

get_protocol_position() {
  declare stack="${1}" protocol="${2}"

  local protocols=$(get_protocols "${stack}")
  local _index=0
  local found="false"
  while read -r line; do
    if [ "${protocol}" = "${line}" ]; then
      found="true"
      break
    fi
    ((_index=$_index+1))
  done < "${JGROUPS_PROTOCOL_ADDS}/${stack}_protocol_list"

  if [ "${found}" = "true" ]; then
    echo ${_index}
  else
    echo -1
  fi
}


