#!/bin/bash
# shellcheck disable=SC1091
source "${JBOSS_HOME}"/bin/probe_common.sh
source "${JBOSS_HOME}"/bin/launch/logging.sh
source "${JBOSS_HOME}"/bin/launch/probe_user.sh

DEBUG=${SCRIPT_DEBUG:-false}
LOG=/tmp/liveness-log
# Ensure the names of to be used probe implementations are interpreted properly
# also when used in double quotes by listing them as array elements
declare -a PROBE_IMPLS=(
    "probe.eap.dmr.EapProbe"
    "probe.eap.dmr.HealthCheckProbe"
)
# Default location of the DMR probe netrc file
PROBE_NETRC_FILE="${PROBE_NETRC_FILE:-/mnt/rh-sso/probe.netrc}"

if ! [ -f "${PROBE_NETRC_FILE}" ]; then
  log_info "Creating a new DMR API probe netrc file."
  # Generate new probe netrc file for DMR API access
  create_probe_netrc_file
fi

if [ $# -gt 0 ] ; then
    DEBUG=$1
    shift
fi

if [ $# -gt 1 ] ; then
    PROBE_IMPLS=("$@")
fi

if [ "$DEBUG" = "true" ]; then
    declare -a DEBUG_OPTIONS=(
        "--debug"
        "--logfile" "${LOG}"
        "--loglevel" "DEBUG"
    )
fi

# Succeed only if DMR probe runner succeeded
if python "${JBOSS_HOME}"/bin/probes/runner.py -c READY -c NOT_READY "${DEBUG_OPTIONS[@]}" "${PROBE_IMPLS[@]}"; then
    exit 0
fi

if [ "$DEBUG" = "true" ]; then
    jps -v | grep standalone | awk '{print $1}' | xargs kill -3
fi

# Otherwise fail
exit 1
