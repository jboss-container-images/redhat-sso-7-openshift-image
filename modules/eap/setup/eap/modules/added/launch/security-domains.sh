
function prepareEnv() {
  unset SECDOMAIN_NAME
  unset SECDOMAIN_USERS_PROPERTIES
  unset SECDOMAIN_ROLES_PROPERTIES
  unset SECDOMAIN_LOGIN_MODULE
  unset SECDOMAIN_PASSWORD_STACKING
}

function configure() {
  configure_security_domains
}

function configureEnv() {
  configure
}

configure_security_domains() {
  local usersProperties="\${jboss.server.config.dir}/${SECDOMAIN_USERS_PROPERTIES}"
  local rolesProperties="\${jboss.server.config.dir}/${SECDOMAIN_ROLES_PROPERTIES}"

  # CLOUD-431: Check if provided files are absolute paths
  test "${SECDOMAIN_USERS_PROPERTIES:0:1}" = "/" && usersProperties="${SECDOMAIN_USERS_PROPERTIES}"
  test "${SECDOMAIN_ROLES_PROPERTIES:0:1}" = "/" && rolesProperties="${SECDOMAIN_ROLES_PROPERTIES}"

  local domains="<!-- no additional security domains configured -->"

  if [ -n "$SECDOMAIN_NAME" ]; then
    local login_module=${SECDOMAIN_LOGIN_MODULE:-UsersRoles}
    local realm=""
    local stack=""

    local confMode
    getConfigurationMode "<!-- ##ADDITIONAL_SECURITY_DOMAINS## -->" "confMode"

    if [ "${confMode}" = "xml" ]; then

      if [ $login_module == "RealmUsersRoles" ]; then
          realm="<module-option name=\"realm\" value=\"ApplicationRealm\"/>\n"
      fi

      if [ -n "$SECDOMAIN_PASSWORD_STACKING" ]; then
          stack="<module-option name=\"password-stacking\" value=\"useFirstPass\"/>\n"
      fi

      domains="\
        <security-domain name=\"$SECDOMAIN_NAME\" cache-type=\"default\">\n\
            <authentication>\n\
                <login-module code=\"$login_module\" flag=\"required\">\n\
                    <module-option name=\"usersProperties\" value=\"${usersProperties}\"/>\n\
                    <module-option name=\"rolesProperties\" value=\"${rolesProperties}\"/>\n\
                    $realm\
                    $stack\
                </login-module>\n\
            </authentication>\n\
        </security-domain>\n"

      sed -i "s|<!-- ##ADDITIONAL_SECURITY_DOMAINS## -->|${domains}<!-- ##ADDITIONAL_SECURITY_DOMAINS## -->|" "$CONFIG_FILE"

    elif [ "${confMode}" = "cli" ]; then

      local moduleOpts=("\"usersProperties\"=>\""${usersProperties}"\""
                        "\"rolesProperties\"=>\""${rolesProperties}"\"")

      if [ $login_module == "RealmUsersRoles" ]; then
          moduleOpts+=("\"realm\"=>\"ApplicationRealm\"")
      fi

      if [ -n "$SECDOMAIN_PASSWORD_STACKING" ]; then
          moduleOpts+=("\"password-stacking\"=>\"useFirstPass\"")
      fi

      cat << EOF >> ${CLI_SCRIPT_FILE}
        if (outcome != success) of /subsystem=security/security-domain=${SECDOMAIN_NAME}:read-resource
          /subsystem=security/security-domain=${SECDOMAIN_NAME}:add(cache-type=default)
          /subsystem=security/security-domain=${SECDOMAIN_NAME}/authentication=classic:add(login-modules=[{code="${login_module}", flag=required, module-options=$(IFS=,; echo "{${moduleOpts[*]}}")}])
        else
          echo "You have set environment variables to configure the security domain '${SECDOMAIN_NAME}'. However, your base configuration already contains a security domain with that name." >> \${error_file}
          quit
        end-if
EOF
    fi
  fi
}