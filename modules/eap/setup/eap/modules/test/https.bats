#!/usr/bin/env bats

source $BATS_TEST_DIRNAME/../../../../../../test-common/cli_utils.sh

# fake JBOSS_HOME
export JBOSS_HOME=$BATS_TMPDIR/jboss_home
rm -rf $JBOSS_HOME 2>/dev/null
mkdir -p $JBOSS_HOME/bin/launch

# copy scripts we are going to use
cp $BATS_TEST_DIRNAME/../../../launch-config/config/added/launch/openshift-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../launch-config/os/added/launch/launch-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../../../../test-common/logging.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/https.sh $JBOSS_HOME/bin/launch

mkdir -p $JBOSS_HOME/standalone/configuration

# Set up the environment variables and load dependencies
WILDFLY_SERVER_CONFIGURATION=standalone-openshift.xml

# source the scripts needed
source $JBOSS_HOME/bin/launch/openshift-common.sh
source $JBOSS_HOME/bin/launch/logging.sh
source $JBOSS_HOME/bin/launch/https.sh


setup() {
  cp $BATS_TEST_DIRNAME/../../../../../../test-common/configuration/standalone-openshift.xml $JBOSS_HOME/standalone/configuration
}

teardown() {
  if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    rm "${CONFIG_FILE}"
  fi
}

@test "Test legacy Https configuration -- Messages if validation fails" {
    expected="INFO Using Elytron for SSL configuration."
    CONFIGURE_ELYTRON_SSL=true
    run configure_https
    [ "${output}" = "${expected}" ]

    CONFIGURE_ELYTRON_SSL=false
    HTTPS_PASSWORD="P@ssw0rd"
    run configure_https
    expected="WARN Partial HTTPS configuration, the https connector WILL NOT be configured."
    [ "${output}" = "${expected}" ]

    [ ! -s "${CLI_SCRIPT_FILE}" ]
}

@test "Test legacy Https configuration -- Verify configure SSL and HTTPS operations" {
    expected=$(cat << EOF
    if (outcome != success) of /core-service=management/security-realm=ApplicationRealm:read-resource
        echo You have set the HTTPS_PASSWORD, HTTPS_KEYSTORE_DIR and HTTPS_KEYSTORE to add the ssl server-identity. Fix your configuration to contain the /core-service=management/security-realm=ApplicationRealm resource for this to happen. >> \${error_file}
        exit
    end-if
    if (outcome == success) of /core-service=management/security-realm=ApplicationRealm/server-identity=ssl:read-resource
        echo You have set the HTTPS_PASSWORD, HTTPS_KEYSTORE_DIR and HTTPS_KEYSTORE to add the ssl server-identity. But this already exists in the base configuration. Fix your configuration. >> \${error_file}
        exit
    end-if
    /core-service=management/security-realm=ApplicationRealm/server-identity=ssl:add(keystore-path="/jboss_home/ssl.key", keystore-password="p@ssw0rd")
    for serverName in /subsystem=undertow:read-children-names(child-type=server)
        /subsystem=undertow/server=\$serverName/https-listener=https:add(security-realm=ApplicationRealm, socket-binding=https, proxy-address-forwarding=true)
    done
EOF
    )

    CONFIG_ADJUSTMENT_MODE="cli"
    CONFIGURE_ELYTRON_SSL=false
    HTTPS_PASSWORD="p@ssw0rd"
    HTTPS_KEYSTORE_DIR="/jboss_home"
    HTTPS_KEYSTORE="ssl.key"

    run configure_https

    output=$(<"${CLI_SCRIPT_FILE}")
    normalize_spaces_new_lines
    [ "${output}" = "${expected}" ]
}