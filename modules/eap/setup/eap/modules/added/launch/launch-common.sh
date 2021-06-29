#!/bin/sh
# common subroutines used in various places of the launch scripts
#
# Start of RH-SSO add-on:
# -----------------------
# Ensure 'CONFIG_ADJUSTMENT_MODE' setting defaults to 'xml_cli' unless previously specified
CONFIG_ADJUSTMENT_MODE="${CONFIG_ADJUSTMENT_MODE:-xml_cli}"
# ----------------------
# Endf of RH-SSO add-on:

# Finds the environment variable  and returns its value if found.
# Otherwise returns the default value if provided.
#
# Arguments:
# $1 env variable name to check
# $2 default value if environment variable was not set
function find_env() {
  var=${!1}
  echo "${var:-$2}"
}

# Finds the environment variable with the given prefix. If not found
# the default value will be returned. If no prefix is provided will rely on
# find_env
#
# Arguments
#  - $1 prefix. Transformed to uppercase and replace - by _
#  - $2 variable name. Prepended by "prefix_"
#  - $3 default value if the variable is not defined
function find_prefixed_env () {
  local prefix=$1

  if [[ -z $prefix ]]; then
    find_env $2 $3
  else
    prefix=${prefix^^} # uppercase
    prefix=${prefix//-/_} #replace - by _

    local var_name=$prefix"_"$2
    echo ${!var_name:-$3}
  fi
}

# Takes the following parameters:
# - $1      - the xml marker to test for
# - $2      - the variable which will hold the result
# The result holding variable, $2, will be populated with one of the following
# three values:
# - ""      - no configuration should be done
# - "xml"   - configuration should happen via marker replacement
# - "cli"   - configuration should happen via cli commands
#
function getConfigurationMode() {
  local marker="${1}"
  unset -v "$2" || echo "Invalid identifier: $2" >&2

  local attemptXml="false"
  local viaCli="false"
  if [ "${CONFIG_ADJUSTMENT_MODE,,}" = "xml" ]; then
    attemptXml="true"
  elif  [ "${CONFIG_ADJUSTMENT_MODE,,}" = "cli" ]; then
    viaCli="true"
  elif  [ "${CONFIG_ADJUSTMENT_MODE,,}" = "xml_cli" ]; then
    attemptXml="true"
    viaCli="true"
  elif [ "${CONFIG_ADJUSTMENT_MODE,,}" != "none" ]; then
    echo "Bad CONFIG_ADJUSTMENT_MODE \'${CONFIG_ADJUSTMENT_MODE}\'"
    exit 1
  fi

  local configVia=""
  if [ "${attemptXml}" = "true" ]; then
    if grep -Fq "${marker}" $CONFIG_FILE; then
        configVia="xml"
    fi
  fi

  if [ -z "${configVia}" ]; then
    if [ "${viaCli}" = "true" ]; then
        configVia="cli"
    fi
  fi

  printf -v "$2" '%s' "${configVia}"
}

# Test an XpathExpression against server config file and returns
# the xmllint exit code
#
# Parameters:
# - $1      - the xpath expression to use
# - $2      - the variable which will hold the exit code
# - $3      - an optional variable to hold the output of the xpath command
#
function testXpathExpression() {
  local xpath="$1"
  unset -v "$2" || echo "Invalid identifier: $2" >&2

  local output
  output=$(eval xmllint --xpath "${xpath}" "${CONFIG_FILE}" 2>/dev/null)

  printf -v "$2" '%s' "$?"

  if [ -n "$3" ]; then
    unset -v "$3" && printf -v "$3" '%s' "${output}"
  fi
}

# An XPath expression e.g getting all name attributes for all the servers in the undertow subsystem
# will return a variable with all the attributes with their names on one line, e.g
#     'name="server-one" name="server-two" name="server-three"'
# Call this with ($input is the string above)
#     convertAttributesToValueOnEachLine "$input" "name"
# to convert this to :
# "server-one
# server-two
# server-three"
function splitAttributesStringIntoLines() {
  local input="${1}"
  local attribute_name="${2}"

  local temp
  temp=$(echo $input | sed "s|\" ${attribute_name}=\"|\" \n${attribute_name}=\"|g" | awk -F "\"" '{print $2}')
  echo "${temp}"
}
