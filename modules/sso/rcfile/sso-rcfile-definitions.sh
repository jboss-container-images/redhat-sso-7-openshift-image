#!/usr/bin/bash
set -e
# NOTE: This script intentionally doesn't include the Bash 'set -u' option
#       (the set builtin option to treat unset variables as errors) on the
#       previous line, since it's included in the RH-SSO container runtime
#       phase too, and there it could cause unsolicited container aborts when
#       checking if some optional runtime env var was specified or not


### RH-SSO global variables & functions

# CIAM-1394 Use a non-printable character - ASCII 31 (octal 037) unit
# separator character as the sed substitute (s) command delimiter for each
# existing call of "sed -i" and "sed -e" across the various container image
# modules, where either the regexp or the replacement value is dynamically
# generated (IOW it's not a fixed string) and it's based on / derived from
# the value of some environment variable.
#
# Do this to avoid clash of the sed substitute command delimiter with some
# special character specified in env var value (e.g. in password), leading to:
#
# * sed: -e expression #1, char <CHAR_POS>: unterminated `s' command
# * sed: -e expression #1, char <CHAR_POS>: unknown option to 's'
#
# type of errors
# shellcheck disable=SC2034
export readonly AUS=$'\037'
