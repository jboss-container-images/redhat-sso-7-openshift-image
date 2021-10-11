#!/usr/bin/env bats

source $BATS_TEST_DIRNAME/../../../../../../test-common/cli_utils.sh

export BATS_TEST_SKIPPED=

# fake JBOSS_HOME
export JBOSS_HOME=$BATS_TMPDIR/jboss_home
rm -rf $JBOSS_HOME 2>/dev/null
mkdir -p $JBOSS_HOME/bin/launch
# copy scripts we are going to use
cp $BATS_TEST_DIRNAME/../../../launch-config/config/added/launch/openshift-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../launch-config/os/added/launch/launch-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../../../../test-common/logging.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/jgroups.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/jgroups_common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/ha.sh $JBOSS_HOME/bin/launch
mkdir -p $JBOSS_HOME/standalone/configuration

# Set up the environment variables and load dependencies
WILDFLY_SERVER_CONFIGURATION=standalone-openshift.xml

# source the scripts needed
source $JBOSS_HOME/bin/launch/openshift-common.sh
source $JBOSS_HOME/bin/launch/logging.sh
source $JBOSS_HOME/bin/launch/ha.sh

export OPENSHIFT_DNS_PING_SERVICE_NAMESPACE="testnamespace"
export CONF_AUTH_MODE="xml"
export CONF_PING_MODE="xml"

setup() {
  cp $BATS_TEST_DIRNAME/../../../../../../test-common/configuration/standalone-openshift.xml $JBOSS_HOME/standalone/configuration
}

teardown() {
  if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    rm "${CONFIG_FILE}"
  fi
}

@test "Validate invalid ping protocol" {
  run validate_ping_protocol "unknown"
  echo "${output}"
  [[ "${output}" =~ "Unknown protocol specified for JGroups discovery protocol:" ]]
}

@test "ping socket binding" {
  run get_socket_binding_for_ping "kubernetes.KUBE_PING"
  echo "${output}"
  [ "${output}" = "" ]
  # run get_socket_binding_for_ping "dns.DNS_PING"
  echo "${output}"
  [ "${output}" = "" ]
  run get_socket_binding_for_ping "openshift.KUBE_PING"
  echo "${output}"
  [ "${output}" = "" ]
  run get_socket_binding_for_ping "openshift.DNS_PING"
  echo "${output}"
  [ "${output}" = "" ]
  run get_socket_binding_for_ping "some.new.PING"
  echo "${output}"
  [ "${output}" = 'socket-binding="jgroups-mping"' ]

}

@test "Generate JGroups Auth config" {
expected=$(cat <<EOF
\n <auth-protocol type="AUTH">\n<digest-token algorithm="digest_algo">\n <shared-secret-reference clear-text="cluster_password"/>\n </digest-token>\n </auth-protocol>\n
EOF
)
  run generate_jgroups_auth_config "cluster_password" "digest_algo"
  output="$(echo "${output}" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected="$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  echo "Result: ${output}"
  echo "Expected: ${expected}"
  [ "${expected}" = "${output}" ]
}

@test "Generate JGroups Auth config - default digest algo" {
expected=$(cat <<EOF
\n <auth-protocol type="AUTH">\n <digest-token algorithm="SHA-512">\n <shared-secret-reference clear-text="cluster_password"/>\n </digest-token>\n </auth-protocol>\n
EOF
)
  run generate_jgroups_auth_config "cluster_password" ""
  output="$(echo "${output}" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected="$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  echo "Result: ${output}"
  echo "Expected: ${expected}"
  [ "${expected}" = "${output}" ]
}


@test "Generate JGroups Auth config - missing cluster password" {
  run generate_jgroups_auth_config "" "digest_algo"
  echo "Result: ${output}"
  [[ "${output}" =~ "No password defined for JGroups cluster." ]]
}

# note openshift.KUBE_PING is aliased to kubernetes.KUBE_PING
@test "Generate JGroups ping config - openshift.KUBE_PING" {
    expected=$(cat <<EOF
WARN Ping protocol openshift.KUBE_PING is deprecated, replacing with kubernetes.KUBE_PING instead.
<protocol type="kubernetes.KUBE_PING" />
EOF
)
  ping_protocol="openshift.KUBE_PING"
  run generate_generic_ping_config "${ping_protocol}"
  echo "Result: ${output}"
  echo "Expected: ${expected}"
  [ "${output}" = "${expected}" ]
}

# note openshift.KUBE_PING is aliased to kubernetes.KUBE_PING
@test "Generate JGroups ping config - openshift.KUBE_PING by generate_dns_ping_config" {
    expected=$(cat <<EOF
WARN Ping protocol openshift.KUBE_PING is deprecated, replacing with kubernetes.KUBE_PING instead.
<protocol type="kubernetes.KUBE_PING" ></protocol>
EOF
)
  ping_protocol="openshift.KUBE_PING"
  run generate_dns_ping_config "${ping_protocol}"
  echo "Result: ${output}"
  echo "Expected: ${expected}"
  [ "${output}" = "${expected}" ]
}

# note openshift.DNS_PING is aliased to dns.DNS_PING
@test "Generate JGroups ping config - openshift.DNS_PING" {
    expected=$(cat <<EOF
WARN Ping protocol openshift.DNS_PING is deprecated, replacing with dns.DNS_PING instead.
<protocol type="dns.DNS_PING" ><property name="dns_query"></property><property name="async_discovery_use_separate_thread_per_request">true</property></protocol>
EOF
)
  ping_protocol="openshift.DNS_PING"
  run generate_dns_ping_config "${ping_protocol}"
  echo "Result: ${output}"
  echo "Expected: ${expected}"
  [ "${output}" = "${expected}" ]
}

# note openshift.DNS_PING is aliased to dns.DNS_PING
@test "Generate JGroups ping config - openshift.DNS_PING by generate_generic_ping_config" {
    expected=$(cat <<EOF
WARN Ping protocol openshift.DNS_PING is deprecated, replacing with dns.DNS_PING instead.
<protocol type="dns.DNS_PING" />
EOF
)
  ping_protocol="openshift.DNS_PING"
  run generate_generic_ping_config "${ping_protocol}"
  echo "Result: ${output}"
  echo "Expected: ${expected}"
  [ "${output}" = "${expected}" ]
}

# check that non-empty OPENSHIFT_DNS_PING_SERVICE_NAME is present when using dns.DNS_PING
@test "Generate JGroups ping config - dns.DNS_PING requires service name" {
    expected=$(cat <<EOF
/tmp/jboss_home/bin/launch/ha.sh: line 295: init_node_name: command not found
ERROR Environment variable OPENSHIFT_DNS_PING_SERVICE_NAME is required when using dns.DNS_PING ping protocol. Please refer to the documentation for configuration.
EOF
)
  export JGROUPS_CLUSTER_PASSWORD="password"
  export JGROUPS_PING_PROTOCOL="dns.DNS_PING"
  export OPENSHIFT_DNS_PING_SERVICE_NAME=""
  run configure_ha
  echo "Result: ${output}"
  echo "Expected: ${expected}"
  [ "${output}" = "${expected}" ]
}

# note openshift.DNS_PING is aliased to dns.DNS_PING
@test "Generate JGroups ping config - openshift.DNS_PING with socket binding" {
    expected=$(cat <<EOF
WARN Ping protocol openshift.DNS_PING is deprecated, replacing with dns.DNS_PING instead.
<protocol type="dns.DNS_PING" socket-binding="sb_value"><property name="dns_query"></property><property name="async_discovery_use_separate_thread_per_request">true</property></protocol>
EOF
)
  ping_protocol="openshift.DNS_PING"
  socket_binding="socket-binding=\"sb_value\""
  run generate_dns_ping_config "${ping_protocol}" "" "" "" "${socket_binding}"
  echo "Result: ${output}"
  echo "Expected: ${expected}"
  [ "${output}" = "${expected}" ]
}

@test "Generate JGroups ping config - kubernetes.KUBE_PING" {
    expected=$(cat <<EOF
<protocol type="kubernetes.KUBE_PING" />
EOF
)
  ping_protocol="kubernetes.KUBE_PING"
  run generate_generic_ping_config "${ping_protocol}"
  echo "Result: ${output}"
  echo "Expected: ${expected}"
  [ "${output}" = "${expected}" ]
}

@test "Generate JGroups ping config - dns.DNS_PING" {
    expected=$(cat <<EOF
<protocol type="dns.DNS_PING" ><property name="dns_query">my-ping-service</property><property name="async_discovery_use_separate_thread_per_request">true</property></protocol>
EOF
)
  ping_protocol="dns.DNS_PING"
  service_port="8888"
  ping_service_name="my-ping-service"
  socket_binding=""
  run generate_dns_ping_config "${ping_protocol}" "${ping_service_name}" "${ping_namespace}" "${socket_binding}"
  echo "Result: ${output}"
  echo "Expected: ${expected}"
  [ "${output}" = "${expected}" ]
}

@test "Test HA configuration file - openshift.KUBE_PING" {
    echo "<!-- ##JGROUPS_AUTH## -->" > $CONFIG_FILE
    echo "<!-- ##JGROUPS_PING_PROTOCOL## -->" >> $CONFIG_FILE
    expected=$(cat <<EOF

 <auth-protocol type="AUTH">
 <digest-token algorithm="clusterdigest">
 <shared-secret-reference clear-text="clusterpassword"/>
 </digest-token>
 </auth-protocol>

<protocol type="kubernetes.KUBE_PING" />
EOF
)
  export JGROUPS_CLUSTER_PASSWORD="clusterpassword"
  export JGROUPS_DIGEST_TOKEN_ALGORITHM="clusterdigest"
  export JGROUPS_PING_PROTOCOL="kubernetes.KUBE_PING"
  run configure_ha
  result=$(<${CONFIG_FILE})
  result="$(echo "<t>${result}</t>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected="$(echo "<t>${expected}</t>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  echo "Result: ${result}"
  echo "Expected: ${expected}"
  [ "${result}" = "${expected}" ]
}

@test "Test HA configuration file - dns.DNS_PING with markers" {
    echo "<!-- ##JGROUPS_AUTH## -->" > $CONFIG_FILE
    echo "<!-- ##JGROUPS_PING_PROTOCOL## -->" >> $CONFIG_FILE
    expected=$(cat <<EOF

 <auth-protocol type="AUTH">
 <digest-token algorithm="SHA-512">
 <shared-secret-reference clear-text="clusterpassword"/>
 </digest-token>
 </auth-protocol>

<protocol type="dns.DNS_PING" ><property name="dns_query">service_name</property><property name="async_discovery_use_separate_thread_per_request">true</property></protocol>
EOF
)
  export JGROUPS_CLUSTER_PASSWORD="clusterpassword"
  export JGROUPS_PING_PROTOCOL="dns.DNS_PING"
  export OPENSHIFT_DNS_PING_SERVICE_PORT="service_port"
  export OPENSHIFT_DNS_PING_SERVICE_NAME="service_name"
  run configure_ha
  result=$(<${CONFIG_FILE})
  result="$(echo "<t>${result}</t>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected="$(echo "<t>${expected}</t>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  echo "Result: ${result}"
  echo "Expected: ${expected}"
  [ "${result}" = "${expected}" ]
}

# note openshift.DNS_PING will be replaced with dns.DNS_PING now
@test "Test HA configuration file - openshift.DNS_PING" {
    echo "<!-- ##JGROUPS_AUTH## -->" > $CONFIG_FILE
    echo "<!-- ##JGROUPS_PING_PROTOCOL## -->" >> $CONFIG_FILE
    expected=$(cat <<EOF

 <auth-protocol type="AUTH">
 <digest-token algorithm="SHA-512">
 <shared-secret-reference clear-text="clusterpassword"/>
 </digest-token>
 </auth-protocol>

<protocol type="dns.DNS_PING" ><property name="dns_query">service_name</property><property name="async_discovery_use_separate_thread_per_request">true</property></protocol>
EOF
)
  export JGROUPS_CLUSTER_PASSWORD="clusterpassword"
  #export JGROUPS_DIGEST_TOKEN_ALGORITHM="clusterdigest"
  export JGROUPS_PING_PROTOCOL="openshift.DNS_PING"
  export OPENSHIFT_DNS_PING_SERVICE_NAME="service_name"
  run configure_ha
  result=$(<${CONFIG_FILE})
  result="$(echo "<t>${result}</t>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected="$(echo "<t>${expected}</t>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  echo "Result: ${result}"
  echo "Expected: ${expected}"
  [ "${result}" = "${expected}" ]
}

@test "Test HA configuration file - AUTH insert order" {
  expected=$(cat <<EOF
        if (outcome != success) of /subsystem=jgroups:read-resource
               echo You have set JGROUPS_CLUSTER_PASSWORD environment variable to configure JGroups authentication protocol. Fix your configuration to contain JGgroups subsystem for this to happen. >> \${error_file}
               quit
         end-if

       if (outcome == success) of /subsystem=jgroups/stack="udp"/protocol="AUTH":read-resource
           echo Cannot configure jgroups 'AUTH' protocol under 'udp' stack. This protocol is already configured. >> \${error_file}
           quit
       end-if

       if (outcome != success) of /subsystem=jgroups/stack="udp"/protocol="AUTH":read-resource
           batch
               /subsystem=jgroups/stack=udp/protocol=AUTH:add(add-index=6)
               /subsystem=jgroups/stack=udp/protocol=AUTH/token=digest:add(algorithm=SHA-512, shared-secret-reference={clear-text=cluster_password})
          run-batch
       end-if

       if (outcome == success) of /subsystem=jgroups/stack="tcp"/protocol="AUTH":read-resource
           echo Cannot configure jgroups 'AUTH' protocol under 'tcp' stack. This protocol is already configured. >> \${error_file}
           quit
       end-if

       if (outcome != success) of /subsystem=jgroups/stack="tcp"/protocol="AUTH":read-resource
           batch
               /subsystem=jgroups/stack=tcp/protocol=AUTH:add(add-index=0)
               /subsystem=jgroups/stack=tcp/protocol=AUTH/token=digest:add(algorithm=SHA-512, shared-secret-reference={clear-text=cluster_password})
          run-batch
       end-if
EOF
)

  cp $BATS_TEST_DIRNAME/server-configs/standalone-openshift-jgroups-auth-gms.xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml

  CONF_AUTH_MODE="cli"
  CONFIG_ADJUSTMENT_MODE="cli"

  JGROUPS_ENCRYPT_SECRET="encrypt_secret"
  JGROUPS_ENCRYPT_NAME="encrypt_name"
  JGROUPS_ENCRYPT_PASSWORD="encrypt_password"
  JGROUPS_ENCRYPT_KEYSTORE="encrypt_keystore"
  JGROUPS_ENCRYPT_KEYSTORE_DIR="keystore_dir"
  JGROUPS_CLUSTER_PASSWORD="cluster_password"

  init_protocol_list_store
  run configure_ha
  echo "CONSOLE: ${output}"
  output=$(cat "${CLI_SCRIPT_FILE}")

  normalize_spaces_new_lines
  echo "${output}" > /tmp/output.txt
  echo "${expected}" > /tmp/expected.txt

  [ "${output}" = "${expected}" ]

}


@test "Test HA configuration file - CLI openshift.DNS_PING" {
    expected=$(cat <<EOF
      if (outcome == success) of /subsystem=jgroups/stack="udp"/protocol="dns.DNS_PING":read-resource
          echo Cannot configure jgroups 'dns.DNS_PING' protocol under 'udp' stack. This protocol is already configured. >> \${error_file}
          quit
      end-if

      if (outcome != success) of /subsystem=jgroups/stack="udp"/protocol="dns.DNS_PING":read-resource
          batch
              /subsystem=jgroups/stack=udp/protocol=dns.DNS_PING:add(add-index=0)
              /subsystem=jgroups/stack=udp/protocol=dns.DNS_PING/property=dns_query:add(value="service_name")
              /subsystem=jgroups/stack=udp/protocol=dns.DNS_PING/property=async_discovery_use_separate_thread_per_request:add(value=true)
        run-batch
      end-if

      if (outcome == success) of /subsystem=jgroups/stack="tcp"/protocol="dns.DNS_PING":read-resource
          echo Cannot configure jgroups 'dns.DNS_PING' protocol under 'tcp' stack. This protocol is already configured. >> \${error_file}
          quit
      end-if

      if (outcome != success) of /subsystem=jgroups/stack="tcp"/protocol="dns.DNS_PING":read-resource
          batch
              /subsystem=jgroups/stack=tcp/protocol=dns.DNS_PING:add(add-index=0)
              /subsystem=jgroups/stack=tcp/protocol=dns.DNS_PING/property=dns_query:add(value="service_name")
              /subsystem=jgroups/stack=tcp/protocol=dns.DNS_PING/property=async_discovery_use_separate_thread_per_request:add(value=true)
        run-batch
      end-if
EOF
)
  JGROUPS_PING_PROTOCOL="dns.DNS_PING"
  OPENSHIFT_DNS_PING_SERVICE_PORT="service_port"
  OPENSHIFT_DNS_PING_SERVICE_NAME="service_name"

  CONF_AUTH_MODE="cli"
  CONFIG_ADJUSTMENT_MODE="cli"

  preConfigure
  run configure_ha

  echo "COSOLE:${output}"
  output=$(<"${CLI_SCRIPT_FILE}")

  normalize_spaces_new_lines
  echo "${output}" > /tmp/output.txt
  echo "${expected}" > /tmp/expected.txt

  [ "${output}" = "${expected}" ]
}

@test "Test HA configuration file - CLI kubernetes.KUBE_PING" {
    expected=$(cat <<EOF
      if (outcome == success) of /subsystem=jgroups/stack="udp"/protocol="kubernetes.KUBE_PING":read-resource
           echo Cannot configure jgroups 'kubernetes.KUBE_PING' protocol under 'udp' stack. This protocol is already configured. >> \${error_file}
           quit
       end-if

       if (outcome != success) of /subsystem=jgroups/stack="udp"/protocol="kubernetes.KUBE_PING":read-resource
           batch
               /subsystem=jgroups/stack=udp/protocol=kubernetes.KUBE_PING:add(add-index=0)
          run-batch
       end-if

       if (outcome == success) of /subsystem=jgroups/stack="tcp"/protocol="kubernetes.KUBE_PING":read-resource
           echo Cannot configure jgroups 'kubernetes.KUBE_PING' protocol under 'tcp' stack. This protocol is already configured. >> \${error_file}
           quit
       end-if

       if (outcome != success) of /subsystem=jgroups/stack="tcp"/protocol="kubernetes.KUBE_PING":read-resource
           batch
               /subsystem=jgroups/stack=tcp/protocol=kubernetes.KUBE_PING:add(add-index=0)
          run-batch
       end-if
EOF
)
  JGROUPS_PING_PROTOCOL="kubernetes.KUBE_PING"

  CONF_AUTH_MODE="cli"
  CONFIG_ADJUSTMENT_MODE="cli"

  preConfigure
  run configure_ha

  echo "COSOLE:${output}"
  output=$(<"${CLI_SCRIPT_FILE}")

  normalize_spaces_new_lines
  echo "${output}" > /tmp/output.txt
  echo "${expected}" > /tmp/expected.txt

  [ "${output}" = "${expected}" ]
}