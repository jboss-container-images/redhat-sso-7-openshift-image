# bug in bats with set -eu?
export BATS_TEST_SKIPPED=

# fake JBOSS_HOME
export JBOSS_HOME=$BATS_TEST_DIRNAME/../../test-common/

source $JBOSS_HOME/launch-common.sh
source ${JBOSS_HOME}/openshift-node-name.sh
source $JBOSS_HOME/logging.sh

# fake the logger so we don't have to deal with colors
export TEST_LOGGING_INCLUDE=$BATS_TEST_DIRNAME/../../test-common/logging.sh
export TEST_LAUNCH_INCLUDE=$BATS_TEST_DIRNAME/../../test-common/launch-common.sh
export TEST_TX_DATASOURCE_INCLUDE=$BATS_TEST_DIRNAME/../../os-eap7-launch/added/launch/tx-datasource.sh
export TEST_NODE_NAME_INCLUDE=$BATS_TEST_DIRNAME/node-name.sh
export TEST_OPENSHIFT_NODE_NAME_INCLUDE=$BATS_TEST_DIRNAME/../../os-eap-node-name/added/launch/openshift-node-name.sh

load $BATS_TEST_DIRNAME/../added/launch/datasource-common.sh

setup() {
  export CONFIG_FILE=${BATS_TMPDIR}/standalone-openshift.xml
}

teardown() {
  if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    rm "${CONFIG_FILE}"
  fi
}

@test "Generate Datasource Common" {

  run generate_datasource_common "pool_nameVal" "jndi_nameVal" "usernameVal" "passwordVal" "hostVal" "portVal" "databasenameVal" \
    "checkerVal" "sorterVal" "driverVal" "servicenameVal" "jtaVal" "validateVal" "urlVal"
  echo ${result}
  echo "Result: ${result}"
  echo "Expected: ${expected}"
  [ "${result}" = "${expected}" ]
}

