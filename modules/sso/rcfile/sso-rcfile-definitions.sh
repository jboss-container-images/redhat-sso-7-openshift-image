#!/usr/bin/bash
set -e
# NOTE: This script intentionally doesn't include the Bash 'set -u' option
#       (the set builtin option to treat unset variables as errors) on the
#       previous line, since it's included in the RH-SSO container runtime
#       phase too, and there it could cause unsolicited container aborts when
#       checking if some optional runtime env var was specified or not


### RH-SSO globally used variables
#
# NOTE: Shell variables intended to be global should be defined at YAML level
#       rather than in this place. Using their YAML level definition ensures
#       they are defined regardless of the way the Bash script of a particular
#       CCT module is executed (interactive vs non-interactive mode) and they
#       are defined also regardless of the user ID, which is used to run the
#       Bash script of a particular CCT module

### RH-SSO globally used functions

# RHSSO-2017 Escape XML special characters to XML escape sequences
function escape_xml_characters() {
  if [[ "$#" -eq "1" ]]
  then
    # Assume the input to be partially XML escaped already
    # Start with XML escaping the ampersand character -- since the input can
    # contain both plain ampersand character and XML escape sequences starting
    # with ampersand too, first unescape the XML escape sequences back to plain
    # characters to identify the occurences of just the plain ampersand
    # character itself. Decode the XML escape sequences using the mapping:
    #
    # https://www.ibm.com/docs/en/was-liberty/base?topic=manually-xml-escape-characters
    #
    input="${1//&amp;/&}"
    input="${input//&apos;/\'}"
    input="${input//&gt;/>}"
    input="${input//&lt;/<}"
    input="${input//&quot;/\"}"
    # Now the ampersand characters still present (remaining) in the input
    # truly represent just the plain ampersand character that should be escaped
    input="${input//&/&amp;}"
    # All ampersands are handled. Now it's safe to XML escape the remaining four
    # characters
    input="${input//\'/&apos;}"
    input="${input//>/&gt;}"
    input="${input//</&lt;}"
    input="${input//\"/&quot;}"
    # Return the resulting XML escaped string
    echo "${input}"
  else
    echo "Please specify exactly one string to be XML escaped."
    exit 1
  fi
}

# RHSSO-2017 Convert XML special characters present in values of existing shell
# environment variables to be valid XML values
#
function sanitize_shell_env_vars_to_valid_xml_values() {
  # Certain shell environment variables have a special function (e.g. HOSTNAME)
  # Avoid their modification (XML escaping) by enumerating them as protected
  declare -ra PROTECTED_SHELL_VARIABLES=(
    # A single control character used as the sed 's' command delimiter
    "AUS"
    # Base set of env vars as known to Red Hat UBI 8 Minimal container image,
    # which need to be protected
    "HOME" "HOSTNAME" "LANG" "OLDPWD" "PATH" "PWD" "SHLVL" "TERM" "_"
    # nss_wrapper specific env vars, which need to be protected
    "LD_PRELOAD" "NSS_WRAPPER_GROUP" "NSS_WRAPPER_PASSWD"
    # EAP layer specific env vars, which need to be protected
    "ADMIN_USERNAME" "ADMIN_PASSWORD"
    "EAP_ADMIN_USERNAME" "EAP_ADMIN_PASSWORD"
    "DEFAULT_ADMIN_USERNAME" # !DEFAULT_ADMIN_PASSWORD variable doesn't exist!
    "SSO_USERNAME" "SSO_PASSWORD"
    # RH-SSO layer specific env vars, which need to be protected
    "SSO_ADMIN_USERNAME" "SSO_ADMIN_PASSWORD" "SSO_REALM"
    "SSO_SERVICE_USERNAME" "SSO_SERVICE_PASSWORD"
  )
  # All shell variables present in RH-SSO container image without lowercase
  # ones also ignoring alias definitions
  declare -ra ALL_SHELL_VARIABLES=(
    $(printenv | grep -P ^[A-Z_]+= | cut -d= -f1 | sort)
  )
  # For better code readability store Bash representation of apostrophe and
  # double quote to local readonly variables for later use
  # Bash apostrophe string is a single apostrophe enclosed with double quotes
  local -r BASH_APOS="'"
  # Bash double quote string is a single double quote enclosed with apostrophes
  local -r BASH_QUOT='"'
  # Modifiable environment variables (their values are safe to be XML escaped)
  # are those from all environment variables which aren't protected
  for var in "${ALL_SHELL_VARIABLES[@]}"
  do
    # Get the current (original) value of the environment variable
    local ORIGINAL_VALUE=$(printenv "${var}")
    if
      # Variable isn't protected
      ! grep -q "${var}" <<< "${PROTECTED_SHELL_VARIABLES[*]}" &&
      # And its value contains at least one of the special XML characters
      grep -Pq "(${BASH_APOS}|${BASH_QUOT}|&|<|>)" <<< "${ORIGINAL_VALUE}"
    then
      # XML escape the original value of the environment variable
      local XML_ESCAPED_VALUE=$(escape_xml_characters "${ORIGINAL_VALUE}")
      # Reset the value of the environment variable to the escaped form
      # First explicitly undefine / remove the variable definition
      if unset -v "${var}"
      then
        # Then export it to subshells with the escaped value again
        export "${var}"="${XML_ESCAPED_VALUE}"
      # If the attempt to remove the variable failed (e.g. because it is
      # a readonly one), that's an unrecoverable error
      else
        echo "Failed to undefine the '${var}' environment variable."
        exit 1
      fi
    fi
  done
}

# RHSSO-2017 Escape characters interpolated when used within sed right-hand
# side expression (namely '&' and ';' characters) with their actual literal
# representation
#
# Per specific SED FAQ section:
#
#   http://sed.sourceforge.net/sedfaq3.html#s3.1.2
#
# the ampersand character is interpolated when used at right-hand side of a
# sed substitute command expression (it is replaced by the entire
# expression matched on the left-hand side). Thus to enter a literal
# ampersand working also for sed on the right-hand side, we need to type a
# '\&'.
#
# Moreover, the backslash (\) character itself needs to be escaped for Bash
# with another backslash per relevant Bash guide section:
#
#  https://www.gnu.org/software/bash/manual/bash.html#ANSI_002dC-Quoting
#
# Thus to enter a literal ampersand working on the right-hand side of the
# sed substitute command, called from Bash script, we need to type '\\&'.
#
function escape_sed_rhs_interpolated_characters() {
  if [[ "$#" -eq "1" ]]
  then
    input="${1//&/\\&}"
    input="${input//;/\\;}"
    # Return the resulting string
    echo "${input}"
  else
    echo "Please specify exactly one string to be escaped"
    echo "for sed right-hand side expression."
    exit 1
  fi
}

### Script body

# Important:
# ----------
#
# RHSSO-2017 Since we want to escape the special XML characters (replace them
# with their XML escape sequence counterparts) possibly present in the values
# of selected environment variables (those that don't have a special meaning to
# the shell itself) in both the current shell environment and also in the
# subsequent child shell sessions, the
# "sanitize_shell_env_vars_to_valid_xml_values()" function below is truly
# intended to be executed RIGHT AWAY in the moment this script definition is
# being Bash "source"d (included in another Bash script / module).
#
# Executing the function right away as part of the sourcing ensures also values
# of the environment variables in the current shell will be sanitized (and via
# export also propagated to subsequent child shells), see e.g.:
#
# * https://stackoverflow.com/a/28489593
# * https://www.man7.org/linux/man-pages/man1/bash.1.html#SHELL_BUILTIN_COMMANDS
#   (see the section dedicated to the 'source' directive)
#
# in contrary to the case when just the copy of the environment variable
# accessible to the subshell, from which the function was called would be
# updated
#
sanitize_shell_env_vars_to_valid_xml_values
