#!/usr/bin/env bats
# dont enable these by default, bats on CI doesn't output anything if they are set
#set -euo pipefail
#IFS=$'\n\t'

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
cp $BATS_TEST_DIRNAME/../added/launch/login-modules-common.sh $JBOSS_HOME/bin/launch
mkdir -p $JBOSS_HOME/standalone/configuration

# Set up the environment variables and load dependencies
WILDFLY_SERVER_CONFIGURATION=standalone-openshift.xml

# source the scripts needed
source $JBOSS_HOME/bin/launch/openshift-common.sh
source $JBOSS_HOME/bin/launch/login-modules-common.sh
source $JBOSS_HOME/bin/launch/logging.sh

setup() {
  cp $BATS_TEST_DIRNAME/../../../../../../test-common/configuration/standalone-openshift.xml $JBOSS_HOME/standalone/configuration
  sed -i "s|<!-- ##OTHER_LOGIN_MODULES## -->| |" "$CONFIG_FILE"
}

teardown() {
  if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    rm "${CONFIG_FILE}"
  fi
}

@test "Configure CLI other security-domain login module " {
  expected=$(cat <<EOF
    if (outcome != success) of /subsystem=security:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the security subsystem. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome != success) of /subsystem=security/security-domain=other:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the other security domain. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome != success) of /subsystem=security/security-domain=other/authentication=classic:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the other security domain authentication configuration. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome == success) of /subsystem=security/security-domain=other/authentication=classic/login-module=Foo:read-resource
          echo "You are adding the login module Foo to other security domain. However, your base configuration already contains it." >> \${error_file}
        else
          /subsystem=security/security-domain=other/authentication=classic/login-module=Foo:add(code=Foo, flag=something, module=org.foo.bar)
        end-if
EOF
)

  run configure_login_modules "Foo" "something" "org.foo.bar"

  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines
  [ "${output}" = "${expected}" ]
}

@test "Configure CLI other security-domain login module no flags no module" {
  expected=$(cat <<EOF
    if (outcome != success) of /subsystem=security:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the security subsystem. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome != success) of /subsystem=security/security-domain=other:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the other security domain. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome != success) of /subsystem=security/security-domain=other/authentication=classic:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the other security domain authentication configuration. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome == success) of /subsystem=security/security-domain=other/authentication=classic/login-module=Foo:read-resource
          echo "You are adding the login module Foo to other security domain. However, your base configuration already contains it." >> \${error_file}
        else
          /subsystem=security/security-domain=other/authentication=classic/login-module=Foo:add(code=Foo, flag=bobo)
        end-if
EOF
)

  run configure_login_modules "Foo" "bobo"

  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines
  [ "${output}" = "${expected}" ]
}

@test "Configure CLI other security-domain login module no flags no module" {
  expected=$(cat <<EOF
    if (outcome != success) of /subsystem=security:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the security subsystem. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome != success) of /subsystem=security/security-domain=other:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the other security domain. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome != success) of /subsystem=security/security-domain=other/authentication=classic:read-resource
          echo "You are adding a login module to other security domain. However, your base configuration doesn't contain the other security domain authentication configuration. Fix your configuration for that to happen." >> \${error_file}
        end-if
        if (outcome == success) of /subsystem=security/security-domain=other/authentication=classic/login-module=Foo:read-resource
          echo "You are adding the login module Foo to other security domain. However, your base configuration already contains it." >> \${error_file}
        else
          /subsystem=security/security-domain=other/authentication=classic/login-module=Foo:add(code=Foo, flag=optional)
        end-if
EOF
)

  run configure_login_modules "Foo"

  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines
  [ "${output}" = "${expected}" ]
}