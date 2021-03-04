#!/usr/bin/env bash

set -e

# Include logging module
# shellcheck source=/dev/null
source "${JBOSS_HOME}/bin/launch/logging.sh"

function postConfigure() {
  verify_CVE_2020_10695_fix_present
  verify_KEYCLOAK_16736_fix_present
}

# KEYCLOAK-13585 / RH BZ#1817530 / CVE-2020-10695:
#
# Runtime /etc/passwd file permissions safety check to prevent
# reintroduction of CVE-2020-10695. !!! DO NOT REMOVE !!!
#
function verify_CVE_2020_10695_fix_present() {
  local etcPasswdPerms
  etcPasswdPerms=$(stat -c '%a' "/etc/passwd")
  local -r errorExitCode="1"
  if [ "${etcPasswdPerms}" -gt "644" ]
  then
    log_error "Permissions '${etcPasswdPerms}' for '/etc/passwd' are too open!"
    log_error "It is recommended the '/etc/passwd' file can only be modified by"
    log_error "root or users with sudo privileges and readable by all system users."
    log_error "Cannot start the '${JBOSS_IMAGE_NAME}', version '${JBOSS_IMAGE_VERSION}'!"
    exit "${errorExitCode}"
  fi
}

# KEYCLOAK-16736:
#
# Verify 'CMD' instruction in the Dockerfile used to build
# the image contains an associated 'WORKDIR' instruction
#
function verify_KEYCLOAK_16736_fix_present() {
  # Intentionally expand to any Dockerfile matching the image name and version,
  # regardless of the particular image release
  # shellcheck disable=SC2061
  # shellcheck disable=SC2086
  local -r ssoImageDockerfile=$(find /root/buildinfo -maxdepth 1 -type f -name Dockerfile-${JBOSS_IMAGE_NAME/\//-}-${JBOSS_IMAGE_VERSION}-*)
  local -r errorExitCode="1"
  # Throw an error if the image doesn't contain a Dockerfile we could check
  if [ "x${ssoImageDockerfile}x" == "xx" ]
  then
    log_error "The specified Dockerfile: '${ssoImageDockerfile}' does not exist!"
    exit "${errorExitCode}"
  # Confirm 'WORKDIR' instruction is defined in that Dockerfile
  elif ! grep -q 'WORKDIR' "${ssoImageDockerfile}"
  then
    log_error "'WORKDIR' instruction is not defined in the ${ssoImageDockerfile} Dockerfile!"
    exit "${errorExitCode}"
  # And its value is identical to the value of $HOME variable
  elif ! grep -q "WORKDIR ${HOME}" "${ssoImageDockerfile}"
  then
    log_error "The value of 'WORKDIR' instruction in the ${ssoImageDockerfile}"
    log_error "doesn't match value of '${HOME}' variable!"
    exit "${errorExitCode}"
  fi
}
