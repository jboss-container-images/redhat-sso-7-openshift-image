#!/usr/bin/env bash

set -e

# Include logging module
# shellcheck source=/dev/null
source "${JBOSS_HOME}/bin/launch/logging.sh"

function postConfigure() {
  verify_CVE_2020_10695_fix_present
  verify_KEYCLOAK_16736_fix_present
  verify_CIAM_1757_fix_present
  #verify_rhsso-2361_fix_present
  #verify_CIAM_1975_fix_present
  #verify_CIAM_2055_fix_present
  #verify_CIAM_2657_fix_present
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
  local -r ssoImageDockerfile=$(find /root/buildinfo -maxdepth 1 -type f -name Dockerfile-${JBOSS_IMAGE_NAME/\//-}-${JBOSS_IMAGE_VERSION}-* 2>/dev/null)
  local -r errorExitCode="1"
  # Throw an error if the image doesn't contain a Dockerfile we could check
  if [ -z "${ssoImageDockerfile}" ]
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

# CIAM-1757:
#
# Confirm JDK 1.8 rpms aren't present in the image, since using JDK 11 already
#
function verify_CIAM_1757_fix_present() {
  local -r errorExitCode="1"
  if [ -n "$(rpm --query --all name=java* version=1.8.0*)" ]
  then
    log_error "JDK 1.8 rpms detected in the image. It is recommended to uninstall them."
    log_error "Cannot start the '${JBOSS_IMAGE_NAME}', version '${JBOSS_IMAGE_VERSION}'!"
    exit "${errorExitCode}"
  fi
}

# CIAM-1975
#
# Verify one-off patch for CIAM-1975 got properly installed to the expected location
#
function verify_CIAM_1975_fix_present() {
  local -r errorExitCode="1"
  if ! find "${JBOSS_HOME}"/modules/system/layers -name '*-rhsso-1974.jar' 2> /dev/null | grep -q .
  then
    log_error "The CIAM-1975 one-off patch wasn't properly installed."
    log_error "Cannot start the '${JBOSS_IMAGE_NAME}', version '${JBOSS_IMAGE_VERSION}'!"
    exit "${errorExitCode}"
  fi
}

# CIAM-2055
#
# Verify one-off patch for CIAM-2055 got properly installed to the expected location
#
function verify_CIAM_2055_fix_present() {
  local -r errorExitCode="1"
  if ! find "${JBOSS_HOME}"/modules/system/layers -name '*-rhsso-2054.jar' 2> /dev/null | grep -q .
  then
    log_error "The CIAM-2055 one-off patch wasn't properly installed."
    log_error "Cannot start the '${JBOSS_IMAGE_NAME}', version '${JBOSS_IMAGE_VERSION}'!"
    exit "${errorExitCode}"
  fi
}

function verify_CIAM_2657_fix_present() {
  local -r errorExitCode="1"
  if ! find "${JBOSS_HOME}"/modules/system/layers -name '*-rhsso-2657.jar' 2> /dev/null | grep -q .
  then
    log_error "The CIAM-2657 one-off patch wasn't properly installed."
    log_error "Cannot start the '${JBOSS_IMAGE_NAME}', version '${JBOSS_IMAGE_VERSION}'!"
    exit "${errorExitCode}"
  fi
}

function verify_rhsso-2361_fix_present() {
  local -r errorExitCode="1"
  md5=$(md5sum $(find "${JBOSS_HOME}"/themes/base/admin/resources/js/authz -name authz-controller.js 2>/dev/null) | cut -d ' ' -f1)
  if [[ "$md5" != "a3f1bf92c00282d12bc52fb0c332880e" ]]
  then
    log_error "The rhsso-2361 one-off patch wasn't properly installed."
    log_error "Cannot start the '${JBOSS_IMAGE_NAME}', version '${JBOSS_IMAGE_VERSION}'!"
    exit "${errorExitCode}"
  fi
}
