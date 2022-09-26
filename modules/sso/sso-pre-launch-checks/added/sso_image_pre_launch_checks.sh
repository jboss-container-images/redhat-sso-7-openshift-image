#!/usr/bin/env bash

set -e

# Include logging module
# shellcheck source=/dev/null
source "${JBOSS_HOME}/bin/launch/logging.sh"

function postConfigure() {
  verify_correct_definition_of_sed_delimiter_character
  verify_CVE_2020_10695_fix_present
  verify_KEYCLOAK_16736_fix_present
  verify_CIAM_1757_fix_present
  #verify_CIAM_1975_fix_present
  #verify_CIAM_2055_fix_present
}

# RHSSO-2191
#
# Verify the AUS env var, used as the sed delimiter character in any sed 's'
# command:
#
# 1) Is defined (is not an empty string),
# 2) Is a control character (octal 000 through 037, or the DEL character),
#    not to clash with any other printable character, possibly present in
#    sed regex/replacement,
# 3) Is it a single character (since sed supports only single-byte characters
#    as delimiters)
#
function verify_correct_definition_of_sed_delimiter_character() {
  local -r errorExitCode="1"
  # Is AUS env var defined and not empty?
  # NOTE: The -v test checks the name of the env var, not its value,
  #       so we intentionally don't use the dollar sign in the next statement.
  if ! [[ -v AUS ]]
  then
    log_error "The AUS environment variable is not set or is empty string."
    log_error "Please define it as it is used as the delimiter character for the sed 's' command."
    exit "${errorExitCode}"
  # Is AUS a control char?
  elif ! [[ "${AUS}" =~ [[:cntrl:]] ]]
  then
    log_error "Only control character (octal codes 000 through 037, and 177)"
    log_error "can be used as the delimiter character for the sed 's' command."
    exit "${errorExitCode}"
  # Is AUS a single character?
  elif [[ "${#AUS}" -ne "1" ]]
  then
    log_error "Only a single-byte character can be used as the delimiter for the sed 's' command."
    exit "${errorExitCode}"
  fi
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
