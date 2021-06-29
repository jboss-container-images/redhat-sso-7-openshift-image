echo $BATS_TEST_DIRNAME
load $BATS_TEST_DIRNAME/../../../../../../../test-common/xml_utils.bash
load $BATS_TEST_DIRNAME/../../../../../../../test-common/log_utils.bash
export JBOSS_HOME=$BATS_TMPDIR/jboss_home

mkdir -p $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../os/node-name/added/launch/openshift-node-name.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../../../../../test-common/logging.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../added/launch/datasource-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../../launch-config/os/added/launch/launch-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../added/launch/tx-datasource.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../added/launch/datasource.sh $JBOSS_HOME/bin/launch
mkdir -p $JBOSS_HOME/standalone/configuration

# Set up the environment variables and load dependencies
WILDFLY_SERVER_CONFIGURATION=standalone-openshift.xml
source $BATS_TEST_DIRNAME/../../../../launch-config/config/added/launch/openshift-common.sh
source $JBOSS_HOME/bin/launch/datasource.sh


setup() {
  cp $BATS_TEST_DIRNAME/../../../../../../../test-common/configuration/standalone-openshift.xml $JBOSS_HOME/standalone/configuration
}

assert_datasources() {
  local expected=$1
  local xpath="//*[local-name()='datasources']"
  assert_xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml "$xpath" $BATS_TEST_DIRNAME/expectations/$expected
}

assert_defaut_bindings() {
  local expected=$1
  local xpath="//*[local-name()='default-bindings']"
  assert_xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml "$xpath" $BATS_TEST_DIRNAME/expectations/$expected
}
