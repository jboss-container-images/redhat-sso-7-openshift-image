
# dont enable these by default, bats on CI doesn't output anything if they are set
#set -euo pipefail
#IFS=$'\n\t'

# bug in bats with set -eu?
export BATS_TEST_SKIPPED=

# fake JBOSS_HOME
export JBOSS_HOME=$BATS_TEST_DIRNAME
# fake the logger so we don't have to deal with colors
export LOGGING_INCLUDE=$BATS_TEST_DIRNAME/../../test-common/logging.sh
export ELYTRON_INCLUDE=$BATS_TEST_DIRNAME/../../jboss-eap-config-elytron/added/launch/elytron.sh
export NODE_NAME_INCLUDE=$BATS_TEST_DIRNAME/node-name.sh

load $BATS_TEST_DIRNAME/../added/launch/jgroups.sh
load $BATS_TEST_DIRNAME/../added/launch/ha.sh

setup() {
  export CONFIG_FILE=${BATS_TMPDIR}/standalone-openshift.xml
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
  run create_jgroups_elytron_encrypt_sym "keystore" "key_alias" "encrypt_password" 
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
  run create_jgroups_elytron_encrypt_sym "keystore1" "key_alias2" "encrypt_password3"
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
    echo '<!-- ##TLS## -->' > ${CONFIG_FILE}
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
    [[ "${output}" =~ "WARN The specified JGroups configuration properties (JGROUPS_ENCRYPT_SECRET, JGROUPS_ENCRYPT_NAME, JGROUPS_ENCRYPT_PASSWORD, JGROUPS_ENCRYPT_KEYSTORE_DIR JGROUPS_ENCRYPT_KEYSTORE) will be ignored when using JGROUPS_ENCRYPT_PROTOCOL=ASYM_ENCRYPT. Only JGROUPS_CLUSTER_PASSWORD is used." ]]

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
