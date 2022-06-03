#!/usr/bin/env bash

function prepareEnv() {
  unset SSO_REALM
  unset IMPORT_REALM_FILE
  unset SSO_SERVICE_USERNAME
  unset SSO_SERVICE_PASSWORD
}

function configure() {
  realm_import
}

function realm_import() {
  if [ -n "${SSO_REALM}" ]; then
    # CIAM-1394 correction
    sed -i "s${AUS}##REALM##${AUS}${SSO_REALM}${AUS}" "${IMPORT_REALM_FILE}"
    # EOF CIAM-1394 correction
    if [ -n "${SSO_SERVICE_USERNAME}" ]; then
      if [ -n "${SSO_SERVICE_PASSWORD}" ]; then
        "${JBOSS_HOME}/bin/add-user-keycloak.sh" -r "${SSO_REALM}" -u "${SSO_SERVICE_USERNAME}" -p "${SSO_SERVICE_PASSWORD}" --roles realm-management/realm-admin
      fi
    fi
    export SSO_IMPORT_FILE="${IMPORT_REALM_FILE}"
  fi
}
