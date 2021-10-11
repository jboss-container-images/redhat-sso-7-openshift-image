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
cp $BATS_TEST_DIRNAME/../../../launch-config/os/added/launch/configure-modules.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../../../../test-common/logging.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/jgroups.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/jgroups_common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/ha.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../elytron/added/launch/elytron.sh $JBOSS_HOME/bin/launch
mkdir -p $JBOSS_HOME/standalone/configuration

# Set up the environment variables and load dependencies
WILDFLY_SERVER_CONFIGURATION=standalone-openshift.xml


# source the scripts needed
source $JBOSS_HOME/bin/launch/jgroups_common.sh
source $JBOSS_HOME/bin/launch/openshift-common.sh
source $JBOSS_HOME/bin/launch/logging.sh
source $JBOSS_HOME/bin/launch/elytron.sh

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

add_protocol_after() {
  declare protocol=$1 stack=$2 after_protocol=$3

  local test_index=$(get_protocol_position "${stack}" "${after_protocol}")
  if [ "${test_index}" -eq -1 ]; then
    echo "ERROR. "${after_protocol}" does not exist in the config file."
    exit
  fi

  local data=$(<"${JGROUPS_PROTOCOL_ADDS}/${stack}_protocol_list")
  local initial_array=(${data})
  add_protocol_at_prosition ${stack} ${protocol} ${test_index}
  data=$(<"${JGROUPS_PROTOCOL_ADDS}/${stack}_protocol_list")
  local result_array=(${data})

  ((new_length=${#initial_array[@]}+1))

  if [ $new_length -ne "${#result_array[@]}" ]; then
    echo "ERROR. It is expected that add_protocol_at_prosition() adds one element"
    exit
  fi

  local i=0
  for element in "${result_array[@]}"; do
    if [ $i -eq ${test_index} ] && [ ! "${result_array[$i]}" = "${protocol}" ]; then
      echo "ERROR. It is expected the possition of the added element is ${test_index}"
      break
    fi
    if [ $i -lt ${test_index} ] && [ ! "${result_array[$i]}" = "${initial_array[$i]}" ]; then
      echo "ERROR. The elements of the protocol lists are incorrect before added index"
      break
    fi
    if [ $i -gt ${test_index} ] && [ ! "${result_array[$i]}" = "${initial_array[(($i-1))]}" ]; then
      echo "ERROR. The elements of the protocol lists are incorrect after added index"
      break
    fi
    ((i=$i+1))
  done

  echo "done"
}

@test "Test protocol list store -- read protocols" {
  cp $BATS_TEST_DIRNAME/server-configs/standalone-openshift-jgroups-protocol-store.xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml
  init_protocol_list_store

  expected="MERGE3
   FD_SOCK
   FD_ALL
   VERIFY_SUSPECT
   UNICAST3
   pbcast.STABLE
   pbcast.GMS
   UFC
   MFC
   FRAG2
   pbcast.NAKACK2"

  run get_protocols "udp"
  normalize_spaces_new_lines

  [ "${output}" = "${expected}" ]

  expected="pbcast.GMS
   MERGE3
   FD_SOCK
   FD_ALL
   VERIFY_SUSPECT
   UNICAST3
   pbcast.STABLE
   MFC
   FRAG2
   pbcast.NAKACK2"

  run get_protocols "tcp"
  normalize_spaces_new_lines

  [ "${output}" = "${expected}" ]
}

@test "Test protocol list store -- Add protocol after a specific one" {
  expected="done"
  cp $BATS_TEST_DIRNAME/server-configs/standalone-openshift-jgroups-protocol-store.xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml
  init_protocol_list_store

  # add as the first one
  run add_protocol_after "TEST_ONE" "udp" "MERGE3"
    echo "output=${output}<<"
  echo "expected=${expected}<<"
  [ "${output}" = "${expected}" ]

  # add at the end
  run add_protocol_after "TEST_TWO" "tcp" "pbcast.NAKACK2"
  [ "${output}" = "${expected}" ]

  # add in the middle
  run add_protocol_after "TEST_THREE" "tcp" "VERIFY_SUSPECT"

  [ "${output}" = "${expected}" ]
}

test_ha_jgroups() {
  source $JBOSS_HOME/bin/launch/configure-modules.sh
}

@test "Test protocol list store -- Run ha.sh and jgroups.sh" {
  expected=$(cat << EOF
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
               /subsystem=jgroups/stack=udp/protocol=AUTH/token=digest:add(algorithm=SHA-512, shared-secret-reference={clear-text=p@ssw0rd})
          run-batch
       end-if
       if (outcome == success) of /subsystem=jgroups/stack="tcp"/protocol="AUTH":read-resource
           echo Cannot configure jgroups 'AUTH' protocol under 'tcp' stack. This protocol is already configured. >> \${error_file}
           quit
       end-if

       if (outcome != success) of /subsystem=jgroups/stack="tcp"/protocol="AUTH":read-resource
           batch
               /subsystem=jgroups/stack=tcp/protocol=AUTH:add(add-index=0)
               /subsystem=jgroups/stack=tcp/protocol=AUTH/token=digest:add(algorithm=SHA-512, shared-secret-reference={clear-text=p@ssw0rd})
          run-batch
       end-if

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


       if (outcome == success) of /subsystem=jgroups/stack="udp"/protocol="ASYM_ENCRYPT":read-resource
           echo Cannot configure jgroups 'ASYM_ENCRYPT' protocol under 'udp' stack. This protocol is already configured. >> \${error_file}
           quit
       end-if

       if (outcome != success) of /subsystem=jgroups/stack="udp"/protocol="ASYM_ENCRYPT":read-resource
           batch
               /subsystem=jgroups/stack=udp/protocol=ASYM_ENCRYPT:add(add-index=12)
               /subsystem=jgroups/stack=udp/protocol=ASYM_ENCRYPT/property=sym_keylength:add(value="128")
               /subsystem=jgroups/stack=udp/protocol=ASYM_ENCRYPT/property=sym_algorithm:add(value="AES/ECB/PKCS5Padding")
               /subsystem=jgroups/stack=udp/protocol=ASYM_ENCRYPT/property=asym_keylength:add(value="512")
               /subsystem=jgroups/stack=udp/protocol=ASYM_ENCRYPT/property=asym_algorithm:add(value="RSA")
               /subsystem=jgroups/stack=udp/protocol=ASYM_ENCRYPT/property=change_key_on_leave:add(value="true")
          run-batch
       end-if
       if (outcome == success) of /subsystem=jgroups/stack="tcp"/protocol="ASYM_ENCRYPT":read-resource
           echo Cannot configure jgroups 'ASYM_ENCRYPT' protocol under 'tcp' stack. This protocol is already configured. >> \${error_file}
           quit
       end-if

       if (outcome != success) of /subsystem=jgroups/stack="tcp"/protocol="ASYM_ENCRYPT":read-resource
           batch
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT:add(add-index=11)
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT/property=sym_keylength:add(value="128")
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT/property=sym_algorithm:add(value="AES/ECB/PKCS5Padding")
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT/property=asym_keylength:add(value="512")
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT/property=asym_algorithm:add(value="RSA")
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT/property=change_key_on_leave:add(value="true")
          run-batch
       end-if
EOF
)

  cp $BATS_TEST_DIRNAME/server-configs/standalone-openshift-jgroups-protocol-store.xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml

  CONFIG_ADJUSTMENT_MODE="cli"
  JGROUPS_ENCRYPT_PROTOCOL="ASYM_ENCRYPT"
  JGROUPS_CLUSTER_PASSWORD="p@ssw0rd"
  JGROUPS_PING_PROTOCOL="dns.DNS_PING"
  OPENSHIFT_DNS_PING_SERVICE_PORT="service_port"
  OPENSHIFT_DNS_PING_SERVICE_NAME="service_name"

  CONFIGURE_SCRIPTS=("$JBOSS_HOME/bin/launch/ha.sh" "$JBOSS_HOME/bin/launch/jgroups.sh")

  run test_ha_jgroups
  echo "CONSOLE:${output}"
  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines

  # expected that AUTH is added after GSM, DNS ping at 0 on each stack, ASYM_ENCRYPT after pbcast.NAKACK2
  [ "${output}" = "${expected}" ]

}