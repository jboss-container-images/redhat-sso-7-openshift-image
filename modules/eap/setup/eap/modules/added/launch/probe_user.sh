#!/bin/bash
# shellcheck disable=SC1091
source "${JBOSS_HOME}"/bin/launch/logging.sh
source "${JBOSS_HOME}"/bin/launch/sso-rcfile-definitions.sh

# Default key length constant value
declare -ir keylen="32"
# Default location of the DMR probe netrc file
PROBE_NETRC_FILE="${PROBE_NETRC_FILE:-/mnt/rh-sso/probe.netrc}"

# Generates a new probe netrc file for DMR API access, or exits with failure if
# some error occurred / some required condition volume condition wasn't met
#
# Required arguments: None, but expects the path of the new DMR API probe netrc
#                     file to be created is specified as the value of the
#                     PROBE_NETRC_FILE environment variable
#
function create_probe_netrc_file() {
  # Disable echoing of expanded commands of this routine even in debug mode
  set +x
  # The 'mountPath' of RH-SSO probe netrc volume as defined in RH-SSO templates
  local -r probe_vol_mount="/mnt/rh-sso"
  # Path to DMR probe netrc file is undefined
  if [ -z "${PROBE_NETRC_FILE}" ]; then
    local -a undefined_PROBE_NETRC_FILE_errmsg=(
      "Please set the PROBE_NETRC_FILE environment variable,"
      "pointing to the path of DMR probe netrc file to create."
    )
    log_error "$(printf '%s\n' "${undefined_PROBE_NETRC_FILE_errmsg[@]}")"
    exit 1
  # Path to DMR probe netrc file is defined, but the file doesn't exist yet
  elif ! [ -f "${PROBE_NETRC_FILE}" ]; then
    # Yet remains to check various characteristics/conditions of the mounted
    # volume, which are still configurable in OpenShift:
    # * Either by direct modification of the particular DeploymentConfig YAML,
    # * Or by editing them using the 'oc' CLI tool
    #
    # Thus perform these checks below
    #
    # Verify the DMR probe netrc file path starts with same directories,
    # as used for the RH-SSO pod volume mountpoint in the templates
    local -r probe_netrc_dir="$(dirname "${PROBE_NETRC_FILE}")"
    if [ "${probe_netrc_dir}" != "${probe_vol_mount}" ]; then
      local -a wrong_dir_prefix_errmsg=(
        "Can't create the DMR probe netrc file outside of '${probe_vol_mount}'"
        "directory. Please update the \$PROBE_NETRC_FILE environment variable."
      )
      log_error "$(printf '%s\n' "${wrong_dir_prefix_errmsg[@]}")"
      exit 1
    # Check a volume is mounted at '/mnt/rh-sso' directory
    elif ! [ -d "${probe_vol_mount}" ]; then
      log_error "Please mount a tmpfs volume at: '${probe_vol_mount}' path."
      exit 1
    # Is tmpfs based, IOW OpenShift emptyDir volume with medium set to 'Memory'
    elif [ "$(stat -f -c %T "${probe_vol_mount}")" != "tmpfs" ]; then
      log_error "The type of '${probe_vol_mount}' volume needs to be 'tmpfs'."
      exit 1
    # The '/mnt/rh-sso' directory is writable & searchable by the current user
    elif  ! [ -w "${probe_vol_mount}" ] || ! [ -x "${probe_vol_mount}" ]; then
      log_error "Missing write / search permission on '${probe_vol_mount}'."
      exit 1
    fi
    # Define DMR probe netrc file items
    local -r probe_host="localhost"
    # shellcheck disable=SC2155
    local -r probe_user=$(generate_random_string "${keylen}")
    # shellcheck disable=SC2155
    local -r probe_pass=$(generate_random_string "${keylen}")
    # And whole netrc file content
    local -r plain="machine ${probe_host} login ${probe_user} password ${probe_pass}"
    local -r key=$(generate_random_string "${keylen}")
    # Encrypt netrc file content
    local -r enc=$(
      openssl enc -a -e -aes-256-cbc -pbkdf2 -pass pass:"${key}" \
      <<< "${plain}" 2>/dev/null | tr -d '\0'
    )
    # Prevent a race condition of multiple parallel probe instances
    # trying to create the netrc file simultaneously at the same time
    local -r netrc_lock_dir="${probe_netrc_dir}/netrc.lock"
    # Attempt to obtain the lock for writing the probe netrc file failed
    # (a parallel probe instance already started to create the netrc file)
    if ! mkdir "${netrc_lock_dir}"; then
      log_warning "Failed to acquire the lock for creating the probe netrc file."
      # No exit with error here. Let the other parallel probe instance to
      # finish the already started probe netrc file setup. Since the username
      # used for probe JBoss DMR API requests is being loaded only later anyway
      # (immediately right before the execution of the DMR query), execute the
      # remainder of the probe and let it possibly to succeed
    # Attempt to obtain the lock for writing the probe netrc file succeeded
    else
      # Prepare the content (without newlines) to save to the probe netrc file
      local probe_netrc_content=$''
      probe_netrc_content+=$(echo "${key}" | tr -d $'\n')
      probe_netrc_content+=$(echo "${enc}" | tr -d $'\n')
      # Save the probe netrc file content only it if doesn't exist yet
      if ! [ -f "${PROBE_NETRC_FILE}" ]; then
          # Overwriting the target file with whole content in a single step
          echo "${probe_netrc_content}" >| "${PROBE_NETRC_FILE}"
          # Confirm the write succeeded (netrc file content isn't corrupted)
          if [ "$(cat "${PROBE_NETRC_FILE}")" == "${probe_netrc_content}" ]; then
            log_info "Probe DMR netrc file successfully written to: ${PROBE_NETRC_FILE}"
          # Something wrong happened (netrc file is corrupted). Exit with error
          # this time (at least one probe instance needs to create it correctly)
          else
            log_error "Failed to write probe DMR netrc file to: ${PROBE_NETRC_FILE}"
            exit 1
          fi
      else
        log_info "'${PROBE_NETRC_FILE}' already exists. Ignoring a request to create it."
        # No exit with error here, just proceed to the readiness/liveness probe
        # code implementation itself and let it possibly to succeed
      fi
      # Remove the lock
      rm -rf "${netrc_lock_dir}"
    fi
  # Path to DMR probe netrc file is defined & the file already exists
  else
    log_info "'${PROBE_NETRC_FILE}' already exists. Ignoring a request to create it."
    # No exit with error here, just proceed to the readiness/liveness probe
    # code implementation itself and let is possibly to succeed
  fi
  # Re-enable echoing of expanded commands when in debug mode
  if [ "${SCRIPT_DEBUG}" == "true" ]; then
    set -x
  fi
}

# Performs a verification a management user with 'username' is known to EAP.
# If the user doesn't exist, it is created. Otherwise the procedure literally
# does nothing
#
# Required arguments: The username of the user to be checked
# Optional arguments: The password of the user to be checked. If not specified,
#                     it is loaded from the previously created netrc file.
#
function ensure_probe_mgmt_user_exists() {
  # Disable echoing of expanded commands of this routine even in debug mode
  set +x
  if [[ "$#" -ne "1" ]] && [[ "$#" -ne "2" ]];
  then
    log_error "Please enter the username of the management user to be checked."
    exit 1
  else
    local -r username="${1}"
    if [[ "$#" -eq "2" ]]; then
      local -r password="${2}"
    else
      local -r password=$(load_probe_netrc_file | cut -d $' ' -f 6)
    fi
    # Create a new management probe user, if it doesn't exist yet
    if "${JBOSS_HOME}"/bin/jboss-cli.sh --connect --commands="/subsystem=elytron/filesystem-realm=ManagementRealm:read-identity(identity=\"${username}\")"; 
    then 
      log_info "Using the '${username}' username to authenticate the probe request against the JBoss DMR API."
    else 
      log_info "Creating a new management probe user for DMR API."
      if "${JBOSS_HOME}"/bin/jboss-cli.sh --connect --commands="/subsystem=elytron/filesystem-realm=ManagementRealm:add-identity(identity=\"${username}\"),/subsystem=elytron/filesystem-realm=ManagementRealm:set-password(clear={password=\"${password}\"}, identity=\"${username}\")";
      then
        log_info "User '${username}' added successfully."
      else
        log_error "Failed to add a new '${username}' management user."
        exit 1
      fi
    fi
  fi
  # Re-enable echoing of expanded commands when in debug mode
  if [ "${SCRIPT_DEBUG}" == "true" ]; then
    set -x
  fi
}

# Loads the previously created DMR probe netrc file and returns its content.
# Or throws an error if loading netrc file failed
#
# Required arguments: None, but assumes the value of the PROBE_NETRC_FILE
#                     environment variable points to the path of previously
#                     created DMR API probe netrc file to be loaded
#
function load_probe_netrc_file() {
  # Disable echoing of expanded commands of this routine even in debug mode
  set +x
  # Path to DMR probe netrc file is undefined or it's not a file
  if [ -z "${PROBE_NETRC_FILE}" ] || ! [ -f "${PROBE_NETRC_FILE}" ]; then
    local -a undefined_PROBE_NETRC_FILE_errmsg=(
      "Please set the PROBE_NETRC_FILE environment variable,"
      "pointing to the path of DMR probe netrc file to load."
    )
    log_error "$(printf '%s' "${undefined_PROBE_NETRC_FILE_errmsg[*]}")"
    exit 1
  # Otherwise
  else
    # shellcheck disable=SC2155
    local key=$(head -c "${keylen}" "${PROBE_NETRC_FILE}")
    # shellcheck disable=SC2155
    local enc=$(tail -c +"$((keylen + 1))" "${PROBE_NETRC_FILE}")
    # Intentionally using an array to split the output of openssl call below,
    # thus disable the corresponding ShellCheck test to quieten the wwarning
    # shellcheck disable=SC2207
    local -a plain=(
      $(
        openssl enc -a -d -aes-256-cbc -pbkdf2 -pass pass:"${key}" \
        <<< "${enc}" 2>/dev/null | tr -d '\0'
      )
    )
    # Check if the DMR probe netrc file was decrypted successfully
    if [ "${#plain[@]}" -eq "0" ]; then
      log_error "Failed to decrypt the content of DMR probe netrc file."
      exit 1
    # Check if the DMR probe netrc file has expected format.
    # See '-n, --netrc' CLI option of curl for an example of simple netrc file
    elif [ "${#plain[@]}" -ne "6" ]; then
      local -a netrc_invalid_form_errmsg=(
        "Unrecognized form of the DMR probe netrc file. Expected was a form of:"
        "\tmachine host.domain.com login myself password secret"
        "See the '-n, --netrc' CLI option of the curl tool for more details."
      )
      log_error "$(printf '%s\n' "${netrc_invalid_form_errmsg[@]}")"
      exit 1
    # Probe DMR netrc file got properly decrypted & follows the expected form
    # Return its content concatenated as string
    else
      echo "${plain[*]}"
    fi
  fi
  # Re-enable echoing of expanded commands when in debug mode
  if [ "${SCRIPT_DEBUG}" == "true" ]; then
    set -x
  fi
}
