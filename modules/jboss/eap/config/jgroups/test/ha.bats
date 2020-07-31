# bug in bats with set -eu?
export BATS_TEST_SKIPPED=

# fake JBOSS_HOME
export JBOSS_HOME=$BATS_TEST_DIRNAME
# fake the logger so we don't have to deal with colors
export LOGGING_INCLUDE=$BATS_TEST_DIRNAME/../../test-common/logging.sh
export ELYTRON_INCLUDE=$BATS_TEST_DIRNAME/../../jboss-eap-config-elytron/added/launch/elytron.sh
export NODE_NAME_INCLUDE=$BATS_TEST_DIRNAME/node-name.sh

load $BATS_TEST_DIRNAME/../added/launch/jgroups.sh
load $BATS_TEST_DIRNAME/../added/launch/ha.sh

export OPENSHIFT_DNS_PING_SERVICE_NAMESPACE="testnamespace"

setup() {
  export CONFIG_FILE=${BATS_TMPDIR}/standalone-openshift.xml
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
  run get_socket_binding_for_ping "dns.DNS_PING"
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
\n <auth-protocol type="AUTH">\n <digest-token algorithm="digest_algo">\n <shared-secret-reference clear-text="cluster_password"/>\n </digest-token>\n </auth-protocol>\n
EOF
)
  run generate_jgroups_auth_config "cluster_password" "digest_algo"
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
  echo "Result: ${result}"
  echo "Expected: ${expected}"
  [ "${result}" = "${expected}" ]
}

@test "Test HA configuration file - dns.DNS_PING" {
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

<protocol type="dns.DNS_PING" ><property name="dns_query"></property><property name="async_discovery_use_separate_thread_per_request">true</property></protocol>
EOF
)
  export JGROUPS_CLUSTER_PASSWORD="clusterpassword"
  #export JGROUPS_DIGEST_TOKEN_ALGORITHM="clusterdigest"
  export JGROUPS_PING_PROTOCOL="openshift.DNS_PING"
  run configure_ha
  result=$(<${CONFIG_FILE})
  echo "Result: ${result}"
  echo "Expected: ${expected}"
  [ "${result}" = "${expected}" ]
}
