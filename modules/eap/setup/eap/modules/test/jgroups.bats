# dont enable these by default, bats on CI doesn't output anything if they are set
#set -euo pipefail
#IFS=$'\n\t'
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
cp $BATS_TEST_DIRNAME/../../../../../../test-common/logging.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/jgroups.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/jgroups_common.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../added/launch/ha.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../elytron/added/launch/elytron.sh $JBOSS_HOME/bin/launch
mkdir -p $JBOSS_HOME/standalone/configuration

# Set up the environment variables and load dependencies
WILDFLY_SERVER_CONFIGURATION=standalone-openshift.xml

# source the scripts needed
source $JBOSS_HOME/bin/launch/openshift-common.sh
source $JBOSS_HOME/bin/launch/elytron.sh
source $JBOSS_HOME/bin/launch/logging.sh
source $JBOSS_HOME/bin/launch/jgroups.sh

setup() {
  cp $BATS_TEST_DIRNAME/../../../../../../test-common/configuration/standalone-openshift.xml $JBOSS_HOME/standalone/configuration
}

teardown() {
  if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    rm "${CONFIG_FILE}"
  fi
}

@test "Configure JGROUPS_PROTOCOL=SYM_ENCRYPT" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <encrypt-protocol type="SYM_ENCRYPT" key-store="keystore" key-alias="key_alias">
     <key-credential-reference clear-text="encrypt_password"/>
   </encrypt-protocol>
EOF
)
  run create_jgroups_elytron_encrypt "SYM_ENCRYPT" "keystore" "key_alias" "encrypt_password"
  xml=${output}
  result=$(echo ${xml} | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Result: ${result}"
  expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Expected: ${expected}"
  [ "${result}" = "${expected}" ]
}

@test "Configure JGROUPS_PROTOCOL=SYM_ENCRYPT - parameter check" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <encrypt-protocol type="SYM_ENCRYPT" key-store="keystore1" key-alias="key_alias2">
     <key-credential-reference clear-text="encrypt_password3"/>
   </encrypt-protocol>
EOF
)
  run create_jgroups_elytron_encrypt "SYM_ENCRYPT" "keystore1" "key_alias2" "encrypt_password3"
  xml=${output}
  result=$(echo ${xml} | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Result: ${result}"
  expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Expected: ${expected}"
  [ "${result}" = "${expected}" ]
}

@test "Configure JGROUPS_PROTOCOL=ASYM_ENCRYPT" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <protocol type="ASYM_ENCRYPT">
     <property name="sym_keylength">sym-keylength-512</property>
     <property name="sym_algorithm">sym-algo-somealgo</property>
     <property name="asym_keylength">asym-keylength-256</property>
     <property name="asym_algorithm">asym-algo-somealgo</property>
     <property name="change_key_on_leave">change-key-on-leave-true</property>
   </protocol>
EOF
)
  run create_jgroups_encrypt_asym "sym-keylength-512" "sym-algo-somealgo" "asym-keylength-256" "asym-algo-somealgo" "change-key-on-leave-true"
  xml=${output}
  result=$(echo ${xml} | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "${result}"
  expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
  [ "${result}" = "${expected}" ]
}

@test "Configure JGROUPS_PROTOCOL=ASYM_ENCRYPT - parameter check" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <protocol type="ASYM_ENCRYPT">
     <property name="sym_keylength">sym-keylength-5122</property>
     <property name="sym_algorithm">sym-algo-somealgo3</property>
     <property name="asym_keylength">asym-keylength-2564</property>
     <property name="asym_algorithm">asym-algo-somealgo5</property>
     <property name="change_key_on_leave">change-key-on-leave-true6</property>
   </protocol>
EOF
)
  run create_jgroups_encrypt_asym "sym-keylength-5122" "sym-algo-somealgo3" "asym-keylength-2564" "asym-algo-somealgo5" "change-key-on-leave-true6"
  xml=${output}
  result=$(echo ${xml} | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "${result}"
  expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
  [ "${result}" = "${expected}" ]
}


@test "Test Elytron legacy config" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <protocol type="SYM_ENCRYPT">
     <property name="provider">SunJCE</property>
     <property name="sym_algorithm">AES</property>
     <property name="encrypt_entire_message">true</property>
     <property name="keystore_name">encrypt_keystore_dir/keystore</property>
     <property name="store_password">keystore-password</property>
     <property name="alias">encrypt_name</property>
   </protocol>

EOF
)
  run create_jgroups_elytron_legacy "keystore" "keystore-password" "encrypt_name" "encrypt_keystore_dir"
  xml=${output}
  result=$(echo ${xml} | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "${result}"
  expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
  [ "${result}" = "${expected}" ]
}

@test "Test validate keystore - valid" {
  run validate_keystore "encrypt_secret" "encrypt_name" "encrypt_password" "encrypt_keystore"
  echo "${output}"
  [ "${output}" = "valid" ]
}

@test "Test validate keystore - missing JGROUPS_ENCRYPT_NAME" {
  run validate_keystore "encrypt_secret" "" "encrypt_password" "encrypt_keystore"
  echo "${output}"
  [ "${output}" = "partial" ]
}

@test "Test validate keystore - missing JGROUPS_ENCRYPT_PASSWORD" {
  run validate_keystore "encrypt_secret" "encrypt_name" "" "encrypt_keystore"
  echo "${output}"
  [ "${output}" = "partial" ]
}

@test "Test validate keystore - missing JGROUPS_ENCRYPT_NAME and JGROUPS_ENCRYPT_SECRET" {
  run validate_keystore "" "" "encrypt_password" "encrypt_keystore"
  echo "${output}"
  [ "${output}" = "missing" ]
}

@test "Test validate keystore legacy" {
  run validate_keystore_legacy "encrypt_secret" "encrypt_name" "encrypt_password" "encrypt_keystore" "encrypt_keystore_dir"
  echo "${output}"
  [ "${output}" = "valid" ]
}

@test "Test validate keystore legacy - missing JGROUPS_ENCRYPT_KEYSTORE_DIR" {
  run validate_keystore_legacy "encrypt_secret" "encrypt_name" "encrypt_password" "encrypt_keystore" ""
  echo "${output}"
  [ "${output}" = "partial" ]
}

@test "Test validate keystore legacy - missing JGROUPS_ENCRYPT_KEYSTORE_DIR and JGROUPS_ENCRYPT_SECRET" {
  run validate_keystore_legacy "" "encrypt_name" "encrypt_password" "encrypt_keystore" ""
  echo "${output}"
  [ "${output}" = "missing" ]
}

@test "Test JGroups configuration - basic SYM_ENCRYPT" {
    echo '<!-- ##ELYTRON_TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##TLS## -->' >> ${CONFIG_FILE}
    echo '<!-- ##JGROUPS_ENCRYPT## -->' >> ${CONFIG_FILE}

    JGROUPS_ENCRYPT_PROTOCOL=
    JGROUPS_ENCRYPT_SECRET=
    JGROUPS_ENCRYPT_NAME=
    JGROUPS_ENCRYPT_PASSWORD=
    JGROUPS_ENCRYPT_KEYSTORE=
    JGROUPS_ENCRYPT_KEYSTORE_DIR=
    JGROUPS_CLUSTER_PASSWORD=

    run configure_jgroups_encryption
    echo "${output}"
    [[ "${output}" =~ "INFO Configuring JGroups cluster traffic encryption protocol to SYM_ENCRYPT." ]]
    [[ "${output}" =~ "WARN Detected missing JGroups encryption configuration, the communication within the cluster WILL NOT be encrypted." ]]

    run has_elytron_tls "${CONFIG_FILE}"
    [ "${output}" = "false" ]
    run has_elytron_keystore "${CONFIG_FILE}"
    [ "${output}" = "true" ]
    run has_elytron_legacy_tls "${CONFIG_FILE}"
    [ "${output}" = "false" ]
}

@test "Test JGroups configuration - SYM_ENCRYPT - legacy" {
    echo '<!-- ##TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##JGROUPS_ENCRYPT## -->' >> ${CONFIG_FILE}

    JGROUPS_ENCRYPT_PROTOCOL=SYM_ENCRYPT
    JGROUPS_ENCRYPT_SECRET="encrypt_secret"
    JGROUPS_ENCRYPT_NAME="encrypt_name"
    JGROUPS_ENCRYPT_PASSWORD="encrypt_password"
    JGROUPS_ENCRYPT_KEYSTORE="encrypt_keystore"
    JGROUPS_ENCRYPT_KEYSTORE_DIR="keystore_dir"
    JGROUPS_CLUSTER_PASSWORD="cluster_password"

    run configure_jgroups_encryption
    echo "${output}"
    run has_elytron_tls "${CONFIG_FILE}"
    echo "${output}"
    [ "${output}" = "false" ]
    run has_elytron_legacy_tls "${CONFIG_FILE}"
    echo "${output}"
    [ "${output}" = "true" ]
}

@test "Test JGroups configuration - basic ASYM_ENCRYPT - no extra params" {
    echo '<!-- ##TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##JGROUPS_ENCRYPT## -->' >> ${CONFIG_FILE}

    JGROUPS_ENCRYPT_PROTOCOL=ASYM_ENCRYPT
    JGROUPS_ENCRYPT_SECRET=
    JGROUPS_ENCRYPT_NAME=
    JGROUPS_ENCRYPT_PASSWORD=
    JGROUPS_ENCRYPT_KEYSTORE=
    JGROUPS_ENCRYPT_KEYSTORE_DIR=
    JGROUPS_CLUSTER_PASSWORD="cluster_password"

    run configure_jgroups_encryption
    echo "${output}"
    [[ "${output}" =~ "INFO Configuring JGroups cluster traffic encryption protocol to ASYM_ENCRYPT." ]]
    [[ "${output}" != "WARN The specified JGroups configuration properties"* ]]

    run has_elytron_tls "${CONFIG_FILE}"
    echo "${output}"
    [ "${output}" = "false" ]
    run has_elytron_keystore "${CONFIG_FILE}"
    echo "${output}"
    [ "${output}" = "false" ]
    run has_elytron_legacy_tls "${CONFIG_FILE}"
    echo "${output}"
    [ "${output}" = "true" ]
}

@test "Test JGroups configuration - basic ASYM_ENCRYPT - extra params" {
    echo '<subsystem xmlns="urn:wildfly:elytron:5.0"></subsystem><!-- ##TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##JGROUPS_ENCRYPT## -->' >> ${CONFIG_FILE}

    JGROUPS_ENCRYPT_PROTOCOL=ASYM_ENCRYPT
    JGROUPS_ENCRYPT_SECRET="encrypt_secret"
    JGROUPS_ENCRYPT_NAME="encrypt_name"
    JGROUPS_ENCRYPT_PASSWORD="encrypt_password"
    JGROUPS_ENCRYPT_KEYSTORE="encrypt_keystore"
    JGROUPS_ENCRYPT_KEYSTORE_DIR="keystore_dir"
    JGROUPS_CLUSTER_PASSWORD="cluster_password"

    run configure_jgroups_encryption
    echo "${output}"
    [[ "${output}" =~ "INFO Configuring JGroups cluster traffic encryption protocol to ASYM_ENCRYPT." ]]
    [[ "${output}" =~ "INFO Detected valid JGroups encryption configuration, the communication within the cluster will be encrypted using ASYM_ENCRYPT and Elytron keystore." ]]

    run has_elytron_tls "${CONFIG_FILE}"
    echo "${output}"
    [ "${output}" = "false" ]
    run has_elytron_keystore "${CONFIG_FILE}"
    echo "${output}"
    [ "${output}" = "false" ]
    run has_elytron_legacy_tls "${CONFIG_FILE}"
    echo "${output}"
    [ "${output}" = "true" ]
}

@test "Configure CLI JGROUPS_PROTOCOL=ASYM_ENCRYPT - Without pbcast.NAKACK2 protocol" {
  expected="You have set JGROUPS_CLUSTER_PASSWORD environment variable to configure ASYM_ENCRYPT protocol but pbcast.NAKACK2 protocol was not found for UDP stack. Fix your configuration to contain the pbcast.NAKACK2 in the JGroups subsystem for this to happen."

  cp $BATS_TEST_DIRNAME/server-configs/standalone-openshift-pbcast.NAKACK2.xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml

  CONFIG_ADJUSTMENT_MODE="cli"

  JGROUPS_ENCRYPT_PROTOCOL="ASYM_ENCRYPT"
  JGROUPS_CLUSTER_PASSWORD="p@ssw0rd"

  init_protocol_list_store
  run configure_jgroups_encryption

  # clean spaces before and after each line
  output=$(cat "${CONFIG_ERROR_FILE}")
  normalize_spaces_new_lines

  [ "${output}" = "${expected}" ]
}

@test "Configure CLI JGROUPS_PROTOCOL=ASYM_ENCRYPT without Elytron " {
  expected=$(cat <<EOF
       if (outcome == success) of /subsystem=jgroups/stack="udp"/protocol="ASYM_ENCRYPT":read-resource
           echo Cannot configure jgroups 'ASYM_ENCRYPT' protocol under 'udp' stack. This protocol is already configured. >> \${error_file}
           quit
       end-if

       if (outcome != success) of /subsystem=jgroups/stack="udp"/protocol="ASYM_ENCRYPT":read-resource
           batch
               /subsystem=jgroups/stack=udp/protocol=ASYM_ENCRYPT:add(add-index=4)
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
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT:add(add-index=4)
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT/property=sym_keylength:add(value="128")
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT/property=sym_algorithm:add(value="AES/ECB/PKCS5Padding")
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT/property=asym_keylength:add(value="512")
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT/property=asym_algorithm:add(value="RSA")
               /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT/property=change_key_on_leave:add(value="true")
          run-batch
       end-if
EOF
)

  cp $BATS_TEST_DIRNAME/server-configs/standalone-openshift-with-elytron.xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml
  CONFIG_ADJUSTMENT_MODE="cli"

  JGROUPS_ENCRYPT_PROTOCOL="ASYM_ENCRYPT"
  JGROUPS_CLUSTER_PASSWORD="p@ssw0rd"

  init_protocol_list_store
  run configure_jgroups_encryption

  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines
  [ "${output}" = "${expected}" ]
}

@test "Configure CLI JGROUPS_PROTOCOL=ASYM_ENCRYPT with Elytron" {
  expected=$(cat <<EOF
    if (outcome == success) of /subsystem=elytron:read-resource
      /subsystem=elytron/key-store="jgroups.jceks":add(credential-reference={clear-text="p@ssw0rd"},type="JCEKS",path="jgroups.jceks", relative-to="jboss.server.config.dir")
    else
      echo "Cannot configure Elytron Key Store. The Elytron subsystem is not present in the server configuration file." >> \${error_file}
      quit
    end-if

    if (outcome == success) of /subsystem=jgroups/stack="udp"/protocol="ASYM_ENCRYPT":read-resource
      echo Cannot configure jgroups 'ASYM_ENCRYPT' protocol under 'udp' stack. This protocol is already configured. >> \${error_file}
      quit
    end-if

    if (outcome != success) of /subsystem=jgroups/stack="udp"/protocol="ASYM_ENCRYPT":read-resource
      batch
        /subsystem=jgroups/stack=udp/protocol=ASYM_ENCRYPT:add(add-index=4, key-store="jgroups.jceks", key-alias="jgroups", key-credential-reference={clear-text="p@ssw0rd"})
      run-batch
    end-if

    if (outcome == success) of /subsystem=jgroups/stack="tcp"/protocol="ASYM_ENCRYPT":read-resource
      echo Cannot configure jgroups 'ASYM_ENCRYPT' protocol under 'tcp' stack. This protocol is already configured. >> \${error_file}
      quit
    end-if

    if (outcome != success) of /subsystem=jgroups/stack="tcp"/protocol="ASYM_ENCRYPT":read-resource
      batch
        /subsystem=jgroups/stack=tcp/protocol=ASYM_ENCRYPT:add(add-index=4, key-store="jgroups.jceks", key-alias="jgroups", key-credential-reference={clear-text="p@ssw0rd"})
      run-batch
    end-if
EOF
)

  cp $BATS_TEST_DIRNAME/server-configs/standalone-openshift-with-elytron.xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml
  CONFIG_ADJUSTMENT_MODE="cli"

  JGROUPS_ENCRYPT_PROTOCOL="ASYM_ENCRYPT"
  JGROUPS_CLUSTER_PASSWORD="p@ssw0rd"

  JGROUPS_ENCRYPT_SECRET="app-secret"
  JGROUPS_ENCRYPT_NAME="jgroups"
  JGROUPS_ENCRYPT_PASSWORD="p@ssw0rd"
  JGROUPS_ENCRYPT_KEYSTORE="jgroups.jceks"


  init_protocol_list_store
  run configure_jgroups_encryption

  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines

  [ "${output}" = "${expected}" ]
}


@test "Configure CLI JGROUPS_PROTOCOL=SYM_ENCRYPT - Using Elytron to configure the keystore" {
    expected=$(cat <<EOF
      if (outcome == success) of /subsystem=elytron:read-resource
         /subsystem=elytron/key-store="encrypt_keystore":add(credential-reference={clear-text="encrypt_password"},type="JCEKS",path="encrypt_keystore", relative-to="keystore_dir")
       else
         echo "Cannot configure Elytron Key Store. The Elytron subsystem is not present in the server configuration file." >> \${error_file}
         quit
       end-if

       if (outcome == success) of /subsystem=jgroups/stack="udp"/protocol="SYM_ENCRYPT":read-resource
           echo Cannot configure jgroups 'SYM_ENCRYPT' protocol under 'udp' stack. This protocol is already configured. >> \${error_file}
           quit
       end-if

       if (outcome != success) of /subsystem=jgroups/stack="udp"/protocol="SYM_ENCRYPT":read-resource
           batch
               /subsystem=jgroups/stack=udp/protocol=SYM_ENCRYPT:add(add-index=4, key-store="encrypt_keystore", key-alias="encrypt_name", key-credential-reference={clear-text="encrypt_password"})
          run-batch
       end-if

       if (outcome == success) of /subsystem=jgroups/stack="tcp"/protocol="SYM_ENCRYPT":read-resource
           echo Cannot configure jgroups 'SYM_ENCRYPT' protocol under 'tcp' stack. This protocol is already configured. >> \${error_file}
           quit
       end-if

       if (outcome != success) of /subsystem=jgroups/stack="tcp"/protocol="SYM_ENCRYPT":read-resource
           batch
               /subsystem=jgroups/stack=tcp/protocol=SYM_ENCRYPT:add(add-index=4, key-store="encrypt_keystore", key-alias="encrypt_name", key-credential-reference={clear-text="encrypt_password"})
          run-batch
       end-if
EOF
)
  cp $BATS_TEST_DIRNAME/server-configs/standalone-openshift-with-elytron.xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml

  CONFIG_ADJUSTMENT_MODE="cli"

  JGROUPS_ENCRYPT_PROTOCOL="SYM_ENCRYPT"
  JGROUPS_ENCRYPT_SECRET="encrypt_secret"
  JGROUPS_ENCRYPT_NAME="encrypt_name"
  JGROUPS_ENCRYPT_PASSWORD="encrypt_password"
  JGROUPS_ENCRYPT_KEYSTORE="encrypt_keystore"
  JGROUPS_ENCRYPT_KEYSTORE_DIR="keystore_dir"
  JGROUPS_CLUSTER_PASSWORD="cluster_password"

  init_protocol_list_store
  run configure_jgroups_encryption
  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines

  [ "${output}" = "${expected}" ]
}

@test "Configure CLI JGROUPS_PROTOCOL=SYM_ENCRYPT - Without Elytron" {
  expected=$(cat <<EOF
        if (outcome == success) of /subsystem=jgroups/stack="udp"/protocol="SYM_ENCRYPT":read-resource
            echo Cannot configure jgroups 'SYM_ENCRYPT' protocol under 'udp' stack. This protocol is already configured. >> \${error_file}
            quit
        end-if

        if (outcome != success) of /subsystem=jgroups/stack="udp"/protocol="SYM_ENCRYPT":read-resource
            batch
                /subsystem=jgroups/stack=udp/protocol=SYM_ENCRYPT:add(add-index=10)
                /subsystem=jgroups/stack=udp/protocol=SYM_ENCRYPT/property=provider:add(value=SunJCE)
                /subsystem=jgroups/stack=udp/protocol=SYM_ENCRYPT/property=sym_algorithm:add(value=AES)
                /subsystem=jgroups/stack=udp/protocol=SYM_ENCRYPT/property=encrypt_entire_message:add(value=true)
                /subsystem=jgroups/stack=udp/protocol=SYM_ENCRYPT/property=keystore_name:add(value="keystore_dir/encrypt_keystore")
                /subsystem=jgroups/stack=udp/protocol=SYM_ENCRYPT/property=store_password:add(value="encrypt_password")
                /subsystem=jgroups/stack=udp/protocol=SYM_ENCRYPT/property=alias:add(value="encrypt_name")
          run-batch
        end-if

        if (outcome == success) of /subsystem=jgroups/stack="tcp"/protocol="SYM_ENCRYPT":read-resource
            echo Cannot configure jgroups 'SYM_ENCRYPT' protocol under 'tcp' stack. This protocol is already configured. >> \${error_file}
            quit
        end-if

        if (outcome != success) of /subsystem=jgroups/stack="tcp"/protocol="SYM_ENCRYPT":read-resource
            batch
                /subsystem=jgroups/stack=tcp/protocol=SYM_ENCRYPT:add(add-index=0)
                /subsystem=jgroups/stack=tcp/protocol=SYM_ENCRYPT/property=provider:add(value=SunJCE)
                /subsystem=jgroups/stack=tcp/protocol=SYM_ENCRYPT/property=sym_algorithm:add(value=AES)
                /subsystem=jgroups/stack=tcp/protocol=SYM_ENCRYPT/property=encrypt_entire_message:add(value=true)
                /subsystem=jgroups/stack=tcp/protocol=SYM_ENCRYPT/property=keystore_name:add(value="keystore_dir/encrypt_keystore")
                /subsystem=jgroups/stack=tcp/protocol=SYM_ENCRYPT/property=store_password:add(value="encrypt_password")
                /subsystem=jgroups/stack=tcp/protocol=SYM_ENCRYPT/property=alias:add(value="encrypt_name")
          run-batch
        end-if

EOF
)
  cp $BATS_TEST_DIRNAME/server-configs/standalone-openshift-jgroups.xml $JBOSS_HOME/standalone/configuration/standalone-openshift.xml

  CONFIG_ADJUSTMENT_MODE="cli"

  JGROUPS_ENCRYPT_PROTOCOL="SYM_ENCRYPT"
  JGROUPS_ENCRYPT_SECRET="encrypt_secret"
  JGROUPS_ENCRYPT_NAME="encrypt_name"
  JGROUPS_ENCRYPT_PASSWORD="encrypt_password"
  JGROUPS_ENCRYPT_KEYSTORE="encrypt_keystore"
  JGROUPS_ENCRYPT_KEYSTORE_DIR="keystore_dir"
  JGROUPS_CLUSTER_PASSWORD="cluster_password"

  init_protocol_list_store
  run configure_jgroups_encryption
  output=$(cat "${CLI_SCRIPT_FILE}")
  normalize_spaces_new_lines

  [ "${output}" = "${expected}" ]
}