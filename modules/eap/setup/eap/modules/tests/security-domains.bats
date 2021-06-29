#!/usr/bin/env bats

export BATS_TEST_SKIPPED=
export JBOSS_HOME=$BATS_TMPDIR/jboss_home

rm -rf $JBOSS_HOME
mkdir -p $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../launch-config/config/added/launch/openshift-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../../../../test-common/logging.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../launch-config/os/added/launch/launch-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/security-domains.sh $JBOSS_HOME/bin/launch
mkdir -p $JBOSS_HOME/standalone/configuration

# Set up the environment variables and load dependencies
WILDFLY_SERVER_CONFIGURATION=standalone-openshift.xml
source $JBOSS_HOME/bin/launch/openshift-common.sh
load $BATS_TEST_DIRNAME/../added/launch/security-domains.sh

setup() {
  cp $BATS_TEST_DIRNAME/../../../../../../test-common/configuration/standalone-openshift.xml $JBOSS_HOME/standalone/configuration
}

teardown() {
  if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    rm "${CONFIG_FILE}"
  fi
}

@test "check security-domain configured" {
  expected=$(cat <<EOF
  <security-domain name="HiThere" cache-type="default">
    <authentication>
        <login-module code="RealmUsersRoles" flag="required">
            <module-option name="usersProperties" value="\${jboss.server.config.dir}/my.user.properties"/>
            <module-option name="rolesProperties" value="\${jboss.server.config.dir}/my.roles.properties"/>
            <module-option name="realm" value="ApplicationRealm"/>
            <module-option name="password-stacking" value="useFirstPass"/>
        </login-module>
    </authentication>
  </security-domain>
EOF
)
  SECDOMAIN_NAME=HiThere
  SECDOMAIN_LOGIN_MODULE=RealmUsersRoles
  SECDOMAIN_PASSWORD_STACKING=true
  SECDOMAIN_USERS_PROPERTIES=my.user.properties
  SECDOMAIN_ROLES_PROPERTIES=my.roles.properties

  run configure

  cat ${CONFIG_FILE}
  result=$(xmllint --xpath "//*[local-name()='security-domain'][@name='HiThere'][@cache-type='default']" $CONFIG_FILE)

  result="$(echo "<test>${result}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected=$(echo "<test>${expected}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Expected: ${expected}"
  echo "Result: ${result}"
  [ "${result}" = "${expected}" ]
}