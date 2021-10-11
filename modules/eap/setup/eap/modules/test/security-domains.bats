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
cp $BATS_TEST_DIRNAME/../added/launch/elytron.sh $JBOSS_HOME/bin/launch
mkdir -p $JBOSS_HOME/standalone/configuration

# Set up the environment variables and load dependencies
WILDFLY_SERVER_CONFIGURATION=standalone-openshift.xml

# source the scripts needed
source $JBOSS_HOME/bin/launch/openshift-common.sh
source $JBOSS_HOME/bin/launch/elytron.sh
source $JBOSS_HOME/bin/launch/logging.sh

setup() {
  cp $BATS_TEST_DIRNAME/../../../../../../test-common/configuration/standalone-openshift.xml $JBOSS_HOME/standalone/configuration
}

teardown() {
  if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    rm "${CONFIG_FILE}"
  fi
}

@test "Configure CLI elytron core realms security domain " {
  expected=$(cat <<EOF
    if (outcome != success) of /subsystem=undertow:read-resource
      echo You have set an ELYTRON_SEC_DOMAIN environment variables to configure an application-security-domain. Fix your configuration to contain undertow subsystem for this to happen. >> \${error_file}
      exit
    end-if
    if (outcome == success) of /subsystem=undertow/application-security-domain=HiThere:read-resource
      echo ELYTRON_SEC_DOMAIN environment variable value conflicts with an existing undertow security domain, server can't be configured. >> \${error_file}
      exit
    else
      /subsystem=undertow/application-security-domain=HiThere:add(security-domain=ApplicationDomain)
    end-if
    if (outcome == success) of /subsystem=ejb3:read-resource
      /subsystem=ejb3/application-security-domain=HiThere:add(security-domain=ApplicationDomain)
    end-if
EOF
)

  ELYTRON_SECDOMAIN_NAME=HiThere
  ELYTRON_SECDOMAIN_CORE_REALM=true

  run configure

  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines
  [ "${output}" = "${expected}" ]
}

@test "Configure CLI elytron custom security domain, relative paths" {
  expected=$(cat <<EOF
    if (outcome == success) of /subsystem=elytron/properties-realm=application-properties-HiThere:read-resource
      echo ELYTRON_SEC_DOMAIN environment variable value conflicts with an existing elytron properties-realm, server can't be configured. >> \${error_file}
      exit
    else
      /subsystem=elytron/properties-realm=application-properties-HiThere:add(users-properties={path=foo-users.properties, relative-to=jboss.server.config.dir, plain-text=true, digest-realm-name="Application Security"}, groups-properties={path=foo-roles.properties, relative-to=jboss.server.config.dir}, groups-attribute=Roles)
    end-if
    if (outcome == success) of /subsystem=elytron/security-domain=HiThere:read-resource
      echo ELYTRON_SEC_DOMAIN environment variable value conflicts with an existing elytron security domain, server can't be configured. >> \${error_file}
      exit
    else
      /subsystem=elytron/security-domain=HiThere:add(realms=[{realm=application-properties-HiThere}], default-realm=application-properties-HiThere, permission-mapper=default-permission-mapper)
    end-if
    if (outcome != success) of /subsystem=undertow:read-resource
      echo You have set an ELYTRON_SEC_DOMAIN environment variables to configure an application-security-domain. Fix your configuration to contain undertow subsystem for this to happen. >> \${error_file}
      exit
    end-if
    if (outcome == success) of /subsystem=undertow/application-security-domain=HiThere:read-resource
      echo ELYTRON_SEC_DOMAIN environment variable value conflicts with an existing undertow security domain, server can't be configured. >> \${error_file}
      exit
    else
      /subsystem=undertow/application-security-domain=HiThere:add(security-domain=HiThere)
    end-if
    if (outcome == success) of /subsystem=ejb3:read-resource
      /subsystem=ejb3/application-security-domain=HiThere:add(security-domain=HiThere)
    end-if
EOF
)

  ELYTRON_SECDOMAIN_NAME=HiThere
  ELYTRON_SECDOMAIN_USERS_PROPERTIES=foo-users.properties
  ELYTRON_SECDOMAIN_ROLES_PROPERTIES=foo-roles.properties

  run configure

  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines
  [ "${output}" = "${expected}" ]
}

@test "Configure CLI elytron custom security domain, absolute paths" {
  expected=$(cat <<EOF
    if (outcome == success) of /subsystem=elytron/properties-realm=application-properties-HiThere2:read-resource
      echo ELYTRON_SEC_DOMAIN environment variable value conflicts with an existing elytron properties-realm, server can't be configured. >> \${error_file}
      exit
    else
      /subsystem=elytron/properties-realm=application-properties-HiThere2:add(users-properties={path=/home/jboss/foo-users.properties, plain-text=true, digest-realm-name="Application Security"}, groups-properties={path=/home/jboss/foo-roles.properties}, groups-attribute=Roles)
    end-if
    if (outcome == success) of /subsystem=elytron/security-domain=HiThere2:read-resource
      echo ELYTRON_SEC_DOMAIN environment variable value conflicts with an existing elytron security domain, server can't be configured. >> \${error_file}
      exit
    else
      /subsystem=elytron/security-domain=HiThere2:add(realms=[{realm=application-properties-HiThere2}], default-realm=application-properties-HiThere2, permission-mapper=default-permission-mapper)
    end-if
    if (outcome != success) of /subsystem=undertow:read-resource
      echo You have set an ELYTRON_SEC_DOMAIN environment variables to configure an application-security-domain. Fix your configuration to contain undertow subsystem for this to happen. >> \${error_file}
      exit
    end-if
    if (outcome == success) of /subsystem=undertow/application-security-domain=HiThere2:read-resource
      echo ELYTRON_SEC_DOMAIN environment variable value conflicts with an existing undertow security domain, server can't be configured. >> \${error_file}
      exit
    else
      /subsystem=undertow/application-security-domain=HiThere2:add(security-domain=HiThere2)
    end-if
    if (outcome == success) of /subsystem=ejb3:read-resource
      /subsystem=ejb3/application-security-domain=HiThere2:add(security-domain=HiThere2)
    end-if
EOF
)

  ELYTRON_SECDOMAIN_NAME=HiThere2
  ELYTRON_SECDOMAIN_USERS_PROPERTIES=/home/jboss/foo-users.properties
  ELYTRON_SECDOMAIN_ROLES_PROPERTIES=/home/jboss/foo-roles.properties

  run configure

  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines
  [ "${output}" = "${expected}" ]
}

@test "Configure CLI elytron custom security domain, validate env" {

  prepareEnv
  ELYTRON_SECDOMAIN_ROLES_PROPERTIES=/home/jboss/foo-users.properties
  ELYTRON_SECDOMAIN_USERS_PROPERTIES=/home/jboss/foo-users.properties
  ELYTRON_SECDOMAIN_NAME=HiThere
  run configure
  [ "$status" -eq 0 ]

  prepareEnv
  # no env failure
  ELYTRON_SECDOMAIN_NAME=HiThere
  run configure
  [ "$status" -eq 1 ]

  prepareEnv
  ELYTRON_SECDOMAIN_CORE_REALM=true
  ELYTRON_SECDOMAIN_NAME=HiThere
  run configure
  [ "$status" -eq 0 ]

  prepareEnv
  ELYTRON_SECDOMAIN_CORE_REALM=true
  ELYTRON_SECDOMAIN_USERS_PROPERTIES=/home/jboss/foo-users.properties
  ELYTRON_SECDOMAIN_NAME=HiThere
  run configure
  [ "$status" -eq 1 ]

  prepareEnv
  ELYTRON_SECDOMAIN_CORE_REALM=true
  ELYTRON_SECDOMAIN_ROLES_PROPERTIES=/home/jboss/foo-users.properties
  ELYTRON_SECDOMAIN_NAME=HiThere
  run configure
  [ "$status" -eq 1 ]

  prepareEnv
  ELYTRON_SECDOMAIN_USERS_PROPERTIES=/home/jboss/foo-users.properties
  ELYTRON_SECDOMAIN_NAME=HiThere
  run configure
  [ "$status" -eq 1 ]

  prepareEnv
  ELYTRON_SECDOMAIN_ROLES_PROPERTIES=/home/jboss/foo-users.properties
  ELYTRON_SECDOMAIN_NAME=HiThere
  run configure
  [ "$status" -eq 1 ]
}