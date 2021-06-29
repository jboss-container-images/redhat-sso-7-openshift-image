# bug in bats with set -eu?
export BATS_TEST_SKIPPED=

echo $BATS_TEST_DIRNAME
load $BATS_TEST_DIRNAME/../../../../../../test-common/xml_utils.bash
load $BATS_TEST_DIRNAME/../../../../../../test-common/log_utils.bash
export JBOSS_HOME=$BATS_TMPDIR/jboss_home


mkdir -p $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../os/node-name/added/launch/openshift-node-name.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../../../../test-common/logging.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/datasource-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../launch-config/os/added/launch/launch-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/tx-datasource.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/datasource.sh $JBOSS_HOME/bin/launch
mkdir -p $JBOSS_HOME/standalone/configuration

# Set up the environment variables and load dependencies
WILDFLY_SERVER_CONFIGURATION=standalone-openshift.xml
source $BATS_TEST_DIRNAME/../../../launch-config/config/added/launch/openshift-common.sh
source $JBOSS_HOME/bin/launch/datasource.sh


setup() {
  cp $BATS_TEST_DIRNAME/../../../../../../test-common/configuration/standalone-openshift.xml $JBOSS_HOME/standalone/configuration
}

teardown() {
  if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    rm "${CONFIG_FILE}"
  fi
}

@test "Generate Datasource Common" {

  expected='<datasource jta="jtaVal" jndi-name="jndi_nameVal" pool-name="pool_nameVal" enabled="true" use-java-context="true" statistics-enabled="${wildfly.datasources.statistics-enabled:${wildfly.statistics-enabled:false}}"> <connection-url>urlVal</connection-url> <driver>driverVal</driver> <security> <user-name>usernameVal</user-name> <password>passwordVal</password> </security> </datasource>'
  export NON_XA_DATASOURCE=true
  run generate_datasource_common "pool_nameVal" "jndi_nameVal" "usernameVal" "passwordVal" "hostVal" "portVal" "databasenameVal" \
    "checkerVal" "sorterVal" "driverVal" "servicenameVal" "jtaVal" "validateVal" "urlVal"
  echo ${result}
  expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "${output}"
  result=$(echo "${output}" | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Result: ${result}"
  echo "Expected: ${expected}"
  [ "${result}" = "${expected}" ]
}