
# dont enable these by default, bats on CI doesn't output anything if they are set
# set -euo pipefail
# IFS=$'\n\t'

export BATS_TEST_SKIPPED=

load $BATS_TEST_DIRNAME/../added/launch/elytron.sh

setup() {
  export CONFIG_FILE=${BATS_TMPDIR}/standalone-openshift.xml
}

teardown() {
  if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    rm "${CONFIG_FILE}"
  fi
}

@test "Check for new elytron marker" {
  echo '<!-- ##ELYTRON_TLS## -->' > ${CONFIG_FILE}
  run has_elytron_tls "${CONFIG_FILE}"
  [ "${output}" = "true" ]
}

@test "Check for new elytron marker not present" {
  echo '<!-- ##XELYTRON_TLSX## -->' > ${CONFIG_FILE}
  run has_elytron_tls "${CONFIG_FILE}"
  [ "${output}" = "false" ]
}

@test "Check for legacy elytron marker" {
  echo '<!-- ##TLS## -->' > ${CONFIG_FILE}
  run has_elytron_legacy_tls "${CONFIG_FILE}"
  [ "${output}" = "true" ]
}

@test "Check for legacy elytron marker not present" {
  echo '<!-- ##XTLSX## -->' > ${CONFIG_FILE}
  run has_elytron_legacy_tls "${CONFIG_FILE}"
  [ "${output}" = "false" ]
}

@test "Check for new elytron keystore present" {
  echo '<!-- ##ELYTRON_KEY_STORE## -->' > ${CONFIG_FILE}
  run has_elytron_keystore "${CONFIG_FILE}"
  [ "${output}" = "true" ]
}

@test "Check for new elytron keystore not present" {
  echo '<!-- ##XELYTRON_KEY_STOREX## -->' > ${CONFIG_FILE}
  run has_elytron_keystore "${CONFIG_FILE}"
  [ "${output}" = "false" ]
}

@test "Insert elytron TLS config skeleton" {
  echo '<!-- ##ELYTRON_TLS## -->' > ${CONFIG_FILE}
  echo '<!-- ##TLS## -->' >> ${CONFIG_FILE}
  run has_elytron_tls "${CONFIG_FILE}"
  [ "${output}" = "true" ]
  run has_elytron_legacy_tls "${CONFIG_FILE}"
  [ "${output}" = "true" ]
  insert_elytron_tls "${CONFIG_FILE}"
  # should remove the tag
  run has_elytron_tls "${CONFIG_FILE}"
  [ "${output}" = "false" ]
  # check that the keystore is present
  run has_elytron_keystore "${CONFIG_FILE}"
  [ "${output}" = "true" ]
  # check legacy marker also gone
  run has_elytron_legacy_tls "${CONFIG_FILE}"
  [ "${output}" = "false" ]
}

@test "Don't insert elytron TLS config skeleton if only legacy present" {
  echo '<!-- ##TLS## -->' > ${CONFIG_FILE}
  run has_elytron_tls "${CONFIG_FILE}"
  [ "${output}" = "false" ]
  insert_elytron_tls "${CONFIG_FILE}"
  run has_elytron_tls "${CONFIG_FILE}"
  [ "${output}" = "false" ]
  run has_elytron_keystore "${CONFIG_FILE}"
  [ "${output}" = "false" ]
}

@test "Verify legacy configuration - relative keystore location - with HTTPS_KEYSTORE_DIR no leading /" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <tls>
     <key-stores>
       <key-store name="LocalhostKeyStore">
         <credential-reference clear-text="https_password"/>
         <implementation type="keystore_type"/>
         <file path="keystore" relative-to="https_keystore_dir"/>
       </key-store>
     </key-stores>
     <key-managers>
       <key-manager name="LocalhostKeyManager" key-store="LocalhostKeyStore">
         <credential-reference clear-text="https_key_password"/>
       </key-manager>
     </key-managers>
     <server-ssl-contexts>
       <server-ssl-context name="LocalhostSslContext" key-manager="LocalhostKeyManager"/>
     </server-ssl-contexts>
   </tls>
EOF
)
    local elytron_key_store=$(create_elytron_keystore "LocalhostKeyStore" "keystore" "https_password" "keystore_type" "https_keystore_dir")
    local elytron_key_manager=$(create_elytron_keymanager "LocalhostKeyManager" "LocalhostKeyStore" "https_key_password")
    local elytron_server_ssl_context=$(create_elytron_ssl_context "LocalhostSslContext" "LocalhostKeyManager")

    run elytron_legacy_config "${elytron_key_store}" "${elytron_key_manager}" "${elytron_server_ssl_context}"
    xml=${output}
    result=$(echo ${xml} | sed 's|\\n||g' | xmllint --format --noblanks -)
    echo ${result}
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${result}" = "${expected}" ]
}

@test "Verify legacy configuration - relative keystore location - with HTTPS_KEYSTORE_DIR no leading /, and no HTTP_KEY_PASSWORD" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <tls>
     <key-stores>
       <key-store name="LocalhostKeyStore">
         <credential-reference clear-text="https_password"/>
         <implementation type="keystore_type"/>
         <file path="keystore" relative-to="https_keystore_dir"/>
       </key-store>
     </key-stores>
     <key-managers>
       <key-manager name="LocalhostKeyManager" key-store="LocalhostKeyStore">
         <credential-reference clear-text="https_password"/>
       </key-manager>
     </key-managers>
     <server-ssl-contexts>
       <server-ssl-context name="LocalhostSslContext" key-manager="LocalhostKeyManager"/>
     </server-ssl-contexts>
   </tls>
EOF
)

    local elytron_key_store=$(create_elytron_keystore "LocalhostKeyStore" "keystore" "https_password" "keystore_type" "https_keystore_dir")
    local elytron_key_manager=$(create_elytron_keymanager "LocalhostKeyManager" "LocalhostKeyStore" "https_password")
    local elytron_server_ssl_context=$(create_elytron_ssl_context "LocalhostSslContext" "LocalhostKeyManager")

    run elytron_legacy_config "${elytron_key_store}" "${elytron_key_manager}" "${elytron_server_ssl_context}"
    xml=${output}
    result=$(echo ${xml} | sed 's|\\n||g' | xmllint --format --noblanks -)
    echo ${result}
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${result}" = "${expected}" ]
}

@test "Verify legacy configuration - relative keystore location - without HTTPS_KEYSTORE_DIR" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <tls>
     <key-stores>
       <key-store name="LocalhostKeyStore">
         <credential-reference clear-text="https_password"/>
         <implementation type="keystore_type"/>
         <file path="keystore" relative-to="jboss.server.config.dir"/>
       </key-store>
     </key-stores>
     <key-managers>
       <key-manager name="LocalhostKeyManager" key-store="LocalhostKeyStore">
         <credential-reference clear-text="https_key_password"/>
       </key-manager>
     </key-managers>
     <server-ssl-contexts>
       <server-ssl-context name="LocalhostSslContext" key-manager="LocalhostKeyManager"/>
     </server-ssl-contexts>
   </tls>
EOF
)
    local elytron_key_store=$(create_elytron_keystore "LocalhostKeyStore" "keystore" "https_password" "keystore_type" "")
    local elytron_key_manager=$(create_elytron_keymanager "LocalhostKeyManager" "LocalhostKeyStore" "https_key_password")
    local elytron_server_ssl_context=$(create_elytron_ssl_context "LocalhostSslContext" "LocalhostKeyManager")

    run elytron_legacy_config "${elytron_key_store}" "${elytron_key_manager}" "${elytron_server_ssl_context}"
    xml=${output}
    result=$(echo "${xml}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${result}" = "${expected}" ]
}

@test "Verify legacy configuration - relative keystore location - with HTTPS_KEYSTORE_DIR and leading /" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <tls>
     <key-stores>
       <key-store name="LocalhostKeyStore">
         <credential-reference clear-text="https_password"/>
         <implementation type="keystore_type"/>
         <file path="/https_keystore_dir/keystore"/>
       </key-store>
     </key-stores>
     <key-managers>
       <key-manager name="LocalhostKeyManager" key-store="LocalhostKeyStore">
         <credential-reference clear-text="https_key_password"/>
       </key-manager>
     </key-managers>
     <server-ssl-contexts>
       <server-ssl-context name="LocalhostSslContext" key-manager="LocalhostKeyManager"/>
     </server-ssl-contexts>
   </tls>
EOF
)
    local elytron_key_store=$(create_elytron_keystore "LocalhostKeyStore" "keystore" "https_password" "keystore_type" "/https_keystore_dir")
    local elytron_key_manager=$(create_elytron_keymanager "LocalhostKeyManager" "LocalhostKeyStore" "https_key_password")
    local elytron_server_ssl_context=$(create_elytron_ssl_context "LocalhostSslContext" "LocalhostKeyManager")

    run elytron_legacy_config "${elytron_key_store}" "${elytron_key_manager}" "${elytron_server_ssl_context}"
    xml=${output}
    result=$(echo "${xml}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${result}" = "${expected}" ]
}

@test "Create elytron key-manager" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <key-manager name="key_manager" key-store="key_store">
     <credential-reference clear-text="key_password"/>
   </key-manager>
EOF
)
    run create_elytron_keymanager "key_manager" "key_store" "key_password"
    xml=${output}
    result=$(echo "${xml}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${result}" = "${expected}" ]
}

@test "Create elytron ssl-context" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <server-ssl-context name="sslContextName" key-manager="keyManagerName"/>
EOF
)
    run create_elytron_ssl_context "sslContextName" "keyManagerName"
    xml=${output}
    result=$(echo "${xml}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    echo "${result}"
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${result}" = "${expected}" ]
}

@test "Create elytron https_connector" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <https-listener name="https-connector-name" socket-binding="socket-binding" ssl-context="ssl-context" proxy-address-forwarding="true"/>
EOF
)
    run create_elytron_https_connector "https-connector-name" "socket-binding" "ssl-context" "true"
    xml=${output}
    result=$(echo "${xml}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    echo "${result}"
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${result}" = "${expected}" ]
}

@test "Create elytron https_connector no proxy forwarding" {
    expected=$(cat <<EOF
<?xml version="1.0"?>
   <https-listener name="https-connector-name" socket-binding="socket-binding" ssl-context="ssl-context" proxy-address-forwarding="false"/>
EOF
)
    run create_elytron_https_connector "https-connector-name" "socket-binding" "ssl-context" "false"
    xml=${output}
    result=$(echo "${xml}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    echo "${result}"
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${result}" = "${expected}" ]
}

@test "Configure HTTPS - no CONFIGURE_ELYTRON_SSL=true" {
    CONFIGURE_ELYTRON_SSL=
    run configure_https
    echo "${output}"
    [ "${output}" = "Using PicketBox SSL configuration." ]
}

@test "Configure HTTPS - CONFIGURE_ELYTRON_SSL=true, missing all required vars" {
    echo '<!-- ##ELYTRON_TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##TLS## -->' >> ${CONFIG_FILE}
    expected='WARNING! Partial HTTPS configuration, the https connector WILL NOT be configured. Missing: HTTPS_PASSWORD HTTPS_KEYSTORE HTTPS_KEYSTORE_TYPE'
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD=
    HTTPS_KEYSTORE=
    HTTPS_KEYSTORE_TYPE=
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR=
    run configure_https
    echo "${output}"
    [ "${output}" = "${expected}" ]
}

@test "Configure HTTPS - CONFIGURE_ELYTRON_SSL=true, missing HTTPS_PASSWORD" {
    echo '<!-- ##ELYTRON_TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##TLS## -->' >> ${CONFIG_FILE}
    expected='WARNING! Partial HTTPS configuration, the https connector WILL NOT be configured. Missing: HTTPS_PASSWORD'
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD=
    HTTPS_KEYSTORE="ks"
    HTTPS_KEYSTORE_TYPE="ks_type"
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR=
    run configure_https
    echo "${output}"
    [ "${output}" = "${expected}" ]
}

@test "Configure HTTPS - CONFIGURE_ELYTRON_SSL=true, missing HTTPS_KEYSTORE_TYPE" {
    echo '<!-- ##ELYTRON_TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##TLS## -->' >> ${CONFIG_FILE}
    expected='WARNING! Partial HTTPS configuration, the https connector WILL NOT be configured. Missing: HTTPS_KEYSTORE_TYPE'
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD="password"
    HTTPS_KEYSTORE="ks"
    HTTPS_KEYSTORE_TYPE=
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR=
    run configure_https
    echo "${output}"
    [ "${output}" = "${expected}" ]
}

@test "Configure HTTPS - CONFIGURE_ELYTRON_SSL=true, missing HTTPS_KEYSTORE" {
    echo '<!-- ##ELYTRON_TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##TLS## -->' >> ${CONFIG_FILE}
    expected='WARNING! Partial HTTPS configuration, the https connector WILL NOT be configured. Missing: HTTPS_KEYSTORE'
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD="password"
    HTTPS_KEYSTORE=
    HTTPS_KEYSTORE_TYPE="ks_type"
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR=
    run configure_https
    echo "${output}"
    [ "${output}" = "${expected}" ]
}

@test "Configure HTTPS - CONFIGURE_ELYTRON_SSL=true, no HTTPS_KEY_PASSWORD" {
    echo '<!-- ##ELYTRON_TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##TLS## -->' >> ${CONFIG_FILE}
    expected='No HTTPS_KEY_PASSWORD was provided; using HTTPS_PASSWORD for Elytron LocalhostKeyManager.'
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD="password"
    HTTPS_KEYSTORE="keystore.ks"
    HTTPS_KEYSTORE_TYPE="ks"
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR=
    run configure_https
    echo "${output}"
    [ "${output}" = "${expected}" ]
}

@test "Configure HTTPS - Basic config" {
    echo '<?xml version="1.0"?>' > ${CONFIG_FILE}
    echo '<!-- ##ELYTRON_TLS## -->' >> ${CONFIG_FILE}
    echo '<!-- ##TLS## -->' >> ${CONFIG_FILE}

expected=$(cat <<EOF
<?xml version="1.0"?>
   <tls>
     <key-stores>
       <key-store name="LocalhostKeyStore">
         <credential-reference clear-text="password"/>
         <implementation type="ks"/>
         <file path="keystore.ks" relative-to="jboss.server.config.dir"/>
       </key-store>
       <!-- ##ELYTRON_KEY_STORE## -->
     </key-stores>
     <key-managers>
       <key-manager name="LocalhostKeyManager" key-store="LocalhostKeyStore">
         <credential-reference clear-text="password"/>
       </key-manager>
       <!-- ##ELYTRON_KEY_MANAGER## -->
     </key-managers>
     <server-ssl-contexts>
       <server-ssl-context name="LocalhostSslContext" key-manager="LocalhostKeyManager"/>
       <!-- ##ELYTRON_SERVER_SSL_CONTEXT## -->
     </server-ssl-contexts>
   </tls>
EOF
)
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD="password"
    HTTPS_KEYSTORE="keystore.ks"
    HTTPS_KEYSTORE_TYPE="ks"
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR=
    run configure_https
    cat "${CONFIG_FILE}"
    output=$(cat "${CONFIG_FILE}" | xmllint --format --noblanks -)
    echo "${output}"
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${output}" = "${expected}" ]
}

@test "Configure HTTPS - HTTPS_KEYSTORE_DIR absolute path" {
    echo '<!-- ##ELYTRON_TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##TLS## -->' >> ${CONFIG_FILE}

expected=$(cat <<EOF
<?xml version="1.0"?>
   <tls>
     <key-stores>
       <key-store name="LocalhostKeyStore">
         <credential-reference clear-text="password"/>
         <implementation type="ks"/>
         <file path="/some/directory/keystore.ks"/>
       </key-store>
       <!-- ##ELYTRON_KEY_STORE## -->
     </key-stores>
     <key-managers>
       <key-manager name="LocalhostKeyManager" key-store="LocalhostKeyStore">
         <credential-reference clear-text="password"/>
       </key-manager>
       <!-- ##ELYTRON_KEY_MANAGER## -->
     </key-managers>
     <server-ssl-contexts>
       <server-ssl-context name="LocalhostSslContext" key-manager="LocalhostKeyManager"/>
       <!-- ##ELYTRON_SERVER_SSL_CONTEXT## -->
     </server-ssl-contexts>
   </tls>
EOF
)
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD="password"
    HTTPS_KEYSTORE="keystore.ks"
    HTTPS_KEYSTORE_TYPE="ks"
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR="/some/directory"
    run configure_https
    output=$(cat "${CONFIG_FILE}" | xmllint --format --noblanks -)
    echo "${output}"
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${output}" = "${expected}" ]
}

@test "Configure HTTPS - HTTPS_KEYSTORE_DIR absolute path, HTTPS_KEY_PASSWORD is set" {
    echo '<!-- ##ELYTRON_TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##TLS## -->' >> ${CONFIG_FILE}

expected=$(cat <<EOF
<?xml version="1.0"?>
   <tls>
     <key-stores>
       <key-store name="LocalhostKeyStore">
         <credential-reference clear-text="password"/>
         <implementation type="ks"/>
         <file path="/some/directory/keystore.ks"/>
       </key-store>
       <!-- ##ELYTRON_KEY_STORE## -->
     </key-stores>
     <key-managers>
       <key-manager name="LocalhostKeyManager" key-store="LocalhostKeyStore">
         <credential-reference clear-text="mykeypassword"/>
       </key-manager>
       <!-- ##ELYTRON_KEY_MANAGER## -->
     </key-managers>
     <server-ssl-contexts>
       <server-ssl-context name="LocalhostSslContext" key-manager="LocalhostKeyManager"/>
       <!-- ##ELYTRON_SERVER_SSL_CONTEXT## -->
     </server-ssl-contexts>
   </tls>
EOF
)
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD="password"
    HTTPS_KEYSTORE="keystore.ks"
    HTTPS_KEYSTORE_TYPE="ks"
    HTTPS_KEY_PASSWORD="mykeypassword"
    HTTPS_KEYSTORE_DIR="/some/directory"
    run configure_https
    output=$(cat "${CONFIG_FILE}" | xmllint --format --noblanks -)
    echo "${output}"
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${output}" = "${expected}" ]
}


@test "Configure HTTPS - legacy configuration - no HTTPS_KEYSTORE_DIR absolute path" {
    echo '<!-- ##TLS## -->' > ${CONFIG_FILE}
expected=$(cat <<EOF
<?xml version="1.0"?>
   <tls>
     <key-stores>
       <key-store name="LocalhostKeyStore">
         <credential-reference clear-text="password"/>
         <implementation type="ks"/>
         <file path="keystore.ks" relative-to="jboss.server.config.dir"/>
       </key-store>
     </key-stores>
     <key-managers>
       <key-manager name="LocalhostKeyManager" key-store="LocalhostKeyStore">
         <credential-reference clear-text="password"/>
       </key-manager>
     </key-managers>
     <server-ssl-contexts>
       <server-ssl-context name="LocalhostSslContext" key-manager="LocalhostKeyManager"/>
     </server-ssl-contexts>
   </tls>
EOF
)
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD="password"
    HTTPS_KEYSTORE="keystore.ks"
    HTTPS_KEYSTORE_TYPE="ks"
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR=
    run configure_https
    output=$(cat "${CONFIG_FILE}" | xmllint --format --noblanks -)
    echo "${output}"
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${output}" = "${expected}" ]
}

@test "Configure HTTPS - legacy configuration - HTTPS_KEYSTORE_DIR absolute path, HTTPS_KEY_PASSWORD set" {
    echo '<!-- ##TLS## -->' > ${CONFIG_FILE}
expected=$(cat <<EOF
<?xml version="1.0"?>
   <tls>
     <key-stores>
       <key-store name="LocalhostKeyStore">
         <credential-reference clear-text="password"/>
         <implementation type="ks"/>
         <file path="/some/directory/keystore.ks"/>
       </key-store>
     </key-stores>
     <key-managers>
       <key-manager name="LocalhostKeyManager" key-store="LocalhostKeyStore">
         <credential-reference clear-text="mykeypassword"/>
       </key-manager>
     </key-managers>
     <server-ssl-contexts>
       <server-ssl-context name="LocalhostSslContext" key-manager="LocalhostKeyManager"/>
     </server-ssl-contexts>
   </tls>
EOF
)
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD="password"
    HTTPS_KEYSTORE="keystore.ks"
    HTTPS_KEYSTORE_TYPE="ks"
    HTTPS_KEY_PASSWORD="mykeypassword"
    HTTPS_KEYSTORE_DIR="/some/directory"
    run configure_https
    output=$(cat "${CONFIG_FILE}" | xmllint --format --noblanks -)
    echo "${output}"
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${output}" = "${expected}" ]
}


@test "Configure HTTPS - legacy configuration - HTTPS_KEYSTORE_DIR absolute path" {
    echo '<!-- ##TLS## -->' > ${CONFIG_FILE}
expected=$(cat <<EOF
<?xml version="1.0"?>
   <tls>
     <key-stores>
       <key-store name="LocalhostKeyStore">
         <credential-reference clear-text="password"/>
         <implementation type="ks"/>
         <file path="/some/directory/keystore.ks"/>
       </key-store>
     </key-stores>
     <key-managers>
       <key-manager name="LocalhostKeyManager" key-store="LocalhostKeyStore">
         <credential-reference clear-text="password"/>
       </key-manager>
     </key-managers>
     <server-ssl-contexts>
       <server-ssl-context name="LocalhostSslContext" key-manager="LocalhostKeyManager"/>
     </server-ssl-contexts>
   </tls>
EOF
)
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD="password"
    HTTPS_KEYSTORE="keystore.ks"
    HTTPS_KEYSTORE_TYPE="ks"
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR="/some/directory"
    run configure_https
    output=$(cat "${CONFIG_FILE}" | xmllint --format --noblanks -)
    echo "${output}"
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${output}" = "${expected}" ]
}

# mixed in with the above, xmllint complains a lot about extra content at end of file,
# so test them separately for now. This test is the same for both legacy and new configs
@test "Configure HTTPS - Test HTTPS Connector - basic https-listener" {
    echo '<!-- ##HTTPS_CONNECTOR## -->' > ${CONFIG_FILE}

expected=$(cat <<EOF
<?xml version="1.0"?>
   <https-listener name="https" socket-binding="https" ssl-context="LocalhostSslContext" proxy-address-forwarding="true"/>
EOF
)
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD="password"
    HTTPS_KEYSTORE="keystore.ks"
    HTTPS_KEYSTORE_TYPE="ks"
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR=
    run configure_https
    cat "${CONFIG_FILE}"
    output=$(cat "${CONFIG_FILE}" | xmllint --format --noblanks -)
    echo "${output}"
    expected=$(echo "${expected}" | sed 's|\\n||g' | xmllint --format --noblanks -)
    [ "${output}" = "${expected}" ]
}

@test "Configure HTTPS - missing required params" {
    echo '<!-- ##TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##ELYTRON_TLS## -->' >> ${CONFIG_FILE}
expected=$(cat <<EOF
<!-- ##TLS## -->
<!-- ##ELYTRON_TLS## -->
EOF
)
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD=
    HTTPS_KEYSTORE=
    HTTPS_KEYSTORE_TYPE=
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR=
    run configure_https
    output=$(cat "${CONFIG_FILE}")
    echo "${output}"
    expected=$(echo "${expected}")
    echo "${expected}"
    [ "${output}" = "${expected}" ]
}

@test "Configure ELYTRON_TLS - only replace once" {
    echo '<!-- ##TLS## -->' > ${CONFIG_FILE}
    echo '<!-- ##ELYTRON_TLS## -->' >> ${CONFIG_FILE}
expected=$(cat <<EOF

         <tls>
            <key-stores>
                <!-- ##ELYTRON_KEY_STORE## -->
            </key-stores>
            <key-managers>
                <!-- ##ELYTRON_KEY_MANAGER## -->
            </key-managers>
            <server-ssl-contexts>
                <!-- ##ELYTRON_SERVER_SSL_CONTEXT## -->
            </server-ssl-contexts>
         </tls>
EOF
)
    CONFIGURE_ELYTRON_SSL=true
    HTTPS_PASSWORD=
    HTTPS_KEYSTORE=
    HTTPS_KEYSTORE_TYPE=
    HTTPS_KEY_PASSWORD=
    HTTPS_KEYSTORE_DIR=
    run insert_elytron_tls_config_if_needed "${CONFIG_FILE}"
    output=$(cat "${CONFIG_FILE}")
    echo "${output}"
    expected=$(echo "${expected}")
    echo "${expected}"
    [ "${output}" = "${expected}" ]
    # now run the substitution again and the content should be the same
    run insert_elytron_tls_config_if_needed "${CONFIG_FILE}"
    output=$(cat "${CONFIG_FILE}")
    echo "${output}"
    expected=$(echo "${expected}")
    echo "${expected}"
    [ "${output}" = "${expected}" ]
}
