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
cp $BATS_TEST_DIRNAME/../added/launch/resource-adapters-common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/resource-adapter.sh $JBOSS_HOME/bin/launch

mkdir -p $JBOSS_HOME/standalone/configuration

# Set up the environment variables and load dependencies
WILDFLY_SERVER_CONFIGURATION=standalone-openshift.xml

# source the scripts needed
source $JBOSS_HOME/bin/launch/openshift-common.sh
source $JBOSS_HOME/bin/launch/logging.sh
source $JBOSS_HOME/bin/launch/resource-adapter.sh


setup() {
  cp $BATS_TEST_DIRNAME/../../../../../../test-common/configuration/standalone-openshift.xml $JBOSS_HOME/standalone/configuration
}

teardown() {
  if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    rm "${CONFIG_FILE}"
  fi
}

@test "Test Resource Adapters -- Verify CLI operations two RA config using all environment variables" {
  expected=$(cat << EOF
  if (outcome != success) of /subsystem=resource-adapters:read-resource
    echo You have set environment variables to configure resource-adapters. Fix your configuration to contain the resource-adapters subsystem for this to happen. >> \${error_file}
    exit
  end-if
  if (outcome == success) of /subsystem=resource-adapters/resource-adapter=activemq-rar-one:read-resource
    echo You have set environment variables to configure the resource-adapter 'activemq-rar-one'. However, your base configuration already contains a resource-adapter with that name. >> \${error_file}
    exit
  end-if
  batch
    /subsystem=resource-adapters/resource-adapter=activemq-rar-one:add(archive="activemq-rar-one.rar", transaction-support="XATransaction")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-one/connection-definitions=ConnectionFactory:add(class-name="org.apache.activemq.ra.ActiveMQManagedConnectionFactory", jndi-name="java:/ConnectionFactory", enabled="true", use-java-context="true", tracking="true", min-pool-size=1, max-pool-size=5, pool-prefill=false, flush-strategy=EntirePool, same-rm-override=false, recovery-username="RecoveryUserName", recovery-password="RecoveryPassword")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-one/connection-definitions=ConnectionFactory/config-properties=Password:add(value="P@ssword1")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-one/connection-definitions=ConnectionFactory/config-properties=ServerUrl:add(value="tcp://1.2.3.4:61616?jms.rmIdFromConnectionId=true")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-one/connection-definitions=ConnectionFactory/config-properties=UserName:add(value="tombrady")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-one/admin-objects="queue/HELLOWORLDMDBQueue":add(class-name="org.apache.activemq.command.ActiveMQQueue", jndi-name="java:/queue/HELLOWORLDMDBQueue", use-java-context=true)
    /subsystem=resource-adapters/resource-adapter=activemq-rar-one/admin-objects="queue/HELLOWORLDMDBQueue"/config-properties=PhysicalName:add(value="queue/HELLOWORLDMDBQueue")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-one/admin-objects="queue/HELLOWORLDMDBTopic":add(class-name="org.apache.activemq.command.ActiveMQTopic", jndi-name="java:/queue/HELLOWORLDMDBTopic", use-java-context=true)
    /subsystem=resource-adapters/resource-adapter=activemq-rar-one/admin-objects="queue/HELLOWORLDMDBTopic"/config-properties=PhysicalName:add(value="queue/HELLOWORLDMDBTopic")
  run-batch

  if (outcome != success) of /subsystem=resource-adapters:read-resource
    echo You have set environment variables to configure resource-adapters. Fix your configuration to contain the resource-adapters subsystem for this to happen. >> \${error_file}
    exit
  end-if
  if (outcome == success) of /subsystem=resource-adapters/resource-adapter=activemq-rar-two:read-resource
    echo You have set environment variables to configure the resource-adapter 'activemq-rar-two'. However, your base configuration already contains a resource-adapter with that name. >> \${error_file}
    exit
  end-if
  batch
    /subsystem=resource-adapters/resource-adapter=activemq-rar-two:add(archive="activemq-rar-two.rar", transaction-support="XATransaction")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-two/connection-definitions=ConnectionFactory:add(class-name="org.apache.activemq.ra.ActiveMQManagedConnectionFactory", jndi-name="java:/ConnectionFactory", enabled="true", use-java-context="true", tracking="true", min-pool-size=1, max-pool-size=5, pool-prefill=false, flush-strategy=EntirePool, same-rm-override=false, recovery-username="RecoveryUserName", recovery-password="RecoveryPassword")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-two/connection-definitions=ConnectionFactory/config-properties=Password:add(value="P@ssword1")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-two/connection-definitions=ConnectionFactory/config-properties=ServerUrl:add(value="tcp://1.2.3.4:61616?jms.rmIdFromConnectionId=true")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-two/connection-definitions=ConnectionFactory/config-properties=UserName:add(value="tombrady")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-two/admin-objects="queue/HELLOWORLDMDBQueue":add(class-name="org.apache.activemq.command.ActiveMQQueue", jndi-name="java:/queue/HELLOWORLDMDBQueue", use-java-context=true)
    /subsystem=resource-adapters/resource-adapter=activemq-rar-two/admin-objects="queue/HELLOWORLDMDBQueue"/config-properties=PhysicalName:add(value="queue/HELLOWORLDMDBQueue")
    /subsystem=resource-adapters/resource-adapter=activemq-rar-two/admin-objects="queue/HELLOWORLDMDBTopic":add(class-name="org.apache.activemq.command.ActiveMQTopic", jndi-name="java:/queue/HELLOWORLDMDBTopic", use-java-context=true)
    /subsystem=resource-adapters/resource-adapter=activemq-rar-two/admin-objects="queue/HELLOWORLDMDBTopic"/config-properties=PhysicalName:add(value="queue/HELLOWORLDMDBTopic")
  run-batch
EOF
)

  CONFIG_ADJUSTMENT_MODE="cli"
  RESOURCE_ADAPTERS="TEST_RA_ONE,TEST_RA_TWO"

  TEST_RA_ONE_ID="activemq-rar-one"
  TEST_RA_ONE_ARCHIVE="activemq-rar-one.rar"
  TEST_RA_ONE_MODULE_SLOT="main"
  TEST_RA_ONE_MODULE_ID="org.jboss.resource-adapter.file"
  TEST_RA_ONE_CONNECTION_CLASS="org.apache.activemq.ra.ActiveMQManagedConnectionFactory"
  TEST_RA_ONE_CONNECTION_JNDI="java:/ConnectionFactory"
  TEST_RA_ONE_PROPERTY_ServerUrl="tcp://1.2.3.4:61616?jms.rmIdFromConnectionId=true"
  TEST_RA_ONE_PROPERTY_UserName="tombrady"
  TEST_RA_ONE_PROPERTY_Password="P@ssword1"
  TEST_RA_ONE_POOL_XA="true"
  TEST_RA_ONE_RECOVERY_USERNAME="RecoveryUserName"
  TEST_RA_ONE_RECOVERY_PASSWORD="RecoveryPassword"
  TEST_RA_ONE_POOL_MIN_SIZE="1"
  TEST_RA_ONE_POOL_MAX_SIZE="5"
  TEST_RA_ONE_POOL_PREFILL="false"
  TEST_RA_ONE_TRACKING="true"
  TEST_RA_ONE_TRANSACTION_SUPPORT="XATransaction"
  TEST_RA_ONE_POOL_IS_SAME_RM_OVERRIDE="false"
  TEST_RA_ONE_POOL_FLUSH_STRATEGY="EntirePool"
  TEST_RA_ONE_ADMIN_OBJECTS="queue,topic"
  TEST_RA_ONE_ADMIN_OBJECT_queue_CLASS_NAME="org.apache.activemq.command.ActiveMQQueue"
  TEST_RA_ONE_ADMIN_OBJECT_queue_PHYSICAL_NAME="queue/HELLOWORLDMDBQueue"
  TEST_RA_ONE_ADMIN_OBJECT_topic_CLASS_NAME="org.apache.activemq.command.ActiveMQTopic"
  TEST_RA_ONE_ADMIN_OBJECT_topic_PHYSICAL_NAME="queue/HELLOWORLDMDBTopic"

  TEST_RA_TWO_ID="activemq-rar-two"
  TEST_RA_TWO_ARCHIVE="activemq-rar-two.rar"
  TEST_RA_TWO_MODULE_SLOT="main"
  TEST_RA_TWO_MODULE_ID="org.jboss.resource-adapter.file"
  TEST_RA_TWO_CONNECTION_CLASS="org.apache.activemq.ra.ActiveMQManagedConnectionFactory"
  TEST_RA_TWO_CONNECTION_JNDI="java:/ConnectionFactory"
  TEST_RA_TWO_PROPERTY_ServerUrl="tcp://1.2.3.4:61616?jms.rmIdFromConnectionId=true"
  TEST_RA_TWO_PROPERTY_UserName="tombrady"
  TEST_RA_TWO_PROPERTY_Password="P@ssword1"
  TEST_RA_TWO_POOL_XA="true"
  TEST_RA_TWO_RECOVERY_USERNAME="RecoveryUserName"
  TEST_RA_TWO_RECOVERY_PASSWORD="RecoveryPassword"
  TEST_RA_TWO_POOL_MIN_SIZE="1"
  TEST_RA_TWO_POOL_MAX_SIZE="5"
  TEST_RA_TWO_POOL_PREFILL="false"
  TEST_RA_TWO_TRACKING="true"
  TEST_RA_TWO_TRANSACTION_SUPPORT="XATransaction"
  TEST_RA_TWO_POOL_IS_SAME_RM_OVERRIDE="false"
  TEST_RA_TWO_POOL_FLUSH_STRATEGY="EntirePool"
  TEST_RA_TWO_ADMIN_OBJECTS="queue,topic"
  TEST_RA_TWO_ADMIN_OBJECT_queue_CLASS_NAME="org.apache.activemq.command.ActiveMQQueue"
  TEST_RA_TWO_ADMIN_OBJECT_queue_PHYSICAL_NAME="queue/HELLOWORLDMDBQueue"
  TEST_RA_TWO_ADMIN_OBJECT_topic_CLASS_NAME="org.apache.activemq.command.ActiveMQTopic"
  TEST_RA_TWO_ADMIN_OBJECT_topic_PHYSICAL_NAME="queue/HELLOWORLDMDBTopic"

  run configure
  echo "Console:${output}"
  output=$(<${CLI_SCRIPT_FILE})
  normalize_spaces_new_lines
  [ "${output}" = "${expected}" ]
}

@test "Test Resource Adapters -- Verify CLI operations one RA without security subsystem" {
  expected=$(cat << EOF
    if (outcome != success) of /subsystem=resource-adapters:read-resource
      echo You have set environment variables to configure resource-adapters. Fix your configuration to contain the resource-adapters subsystem for this to happen. >> \${error_file}
      exit
    end-if
    if (outcome == success) of /subsystem=resource-adapters/resource-adapter=activemq-rar-one:read-resource
      echo You have set environment variables to configure the resource-adapter 'activemq-rar-one'. However, your base configuration already contains a resource-adapter with that name. >> \${error_file}
      exit
    end-if
    batch
      /subsystem=resource-adapters/resource-adapter=activemq-rar-one:add(archive="activemq-rar-one.rar")
      /subsystem=resource-adapters/resource-adapter=activemq-rar-one/connection-definitions=ConnectionFactory:add(class-name="org.apache.activemq.ra.ActiveMQManagedConnectionFactory", jndi-name="java:/ConnectionFactory", enabled="true", use-java-context="true", elytron-enabled=true, recovery-elytron-enabled=true)
    run-batch
EOF
)

  CONFIG_ADJUSTMENT_MODE="cli"

  sed -i '/<subsystem xmlns="urn:jboss:domain:security:/,/<\/subsystem>/d' "${CONFIG_FILE}"

  RESOURCE_ADAPTERS="TEST_RA_ONE"
  TEST_RA_ONE_ID="activemq-rar-one"
  TEST_RA_ONE_ARCHIVE="activemq-rar-one.rar"
  TEST_RA_ONE_CONNECTION_CLASS="org.apache.activemq.ra.ActiveMQManagedConnectionFactory"
  TEST_RA_ONE_CONNECTION_JNDI="java:/ConnectionFactory"

  run configure

  output=$(<${CLI_SCRIPT_FILE})
  normalize_spaces_new_lines
  [ "${output}" = "${expected}" ]
}


@test "Test Resource Adapters -- One RA without security and without Elytron" {
  CONFIG_ADJUSTMENT_MODE="cli"

  expected="Elytron subsystem is not present. resource-adapter connection-definition can't be added. Fix your configuration."

  sed -i '/<subsystem xmlns="urn:jboss:domain:security:/,/<\/subsystem>/d' "${CONFIG_FILE}"
  sed -i '/<subsystem xmlns="urn:wildfly:elytron:/,/<\/subsystem>/d' "${CONFIG_FILE}"

  RESOURCE_ADAPTERS="TEST_RA_ONE"
  TEST_RA_ONE_ID="activemq-rar-one"
  TEST_RA_ONE_ARCHIVE="activemq-rar-one.rar"
  TEST_RA_ONE_CONNECTION_CLASS="org.apache.activemq.ra.ActiveMQManagedConnectionFactory"
  TEST_RA_ONE_CONNECTION_JNDI="java:/ConnectionFactory"

  run configure

  output=$(<"${CONFIG_ERROR_FILE}")
  normalize_spaces_new_lines

  [ "${output}" = "${expected}" ]
}