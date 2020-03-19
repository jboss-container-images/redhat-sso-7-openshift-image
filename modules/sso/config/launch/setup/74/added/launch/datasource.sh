source $JBOSS_HOME/bin/launch/datasource-common.sh

function prepareEnv() {
  clearDatasourcesEnv
  clearTxDatasourceEnv
}

function configure() {
  NON_XA_DATASOURCE="true"
  DB_JNDI="java:jboss/datasources/KeycloakDS"
  DB_POOL="KeycloakDS"

  # KEYCLOAK-10858 - if DB_SERVICE_PREFIX_MAPPING variable was provided to the pod,
  # derive XA connection properties & DB driver information from it to avoid WFLYJCA0069 error
  if [ -n "${DB_SERVICE_PREFIX_MAPPING}" ]; then
    # DB_SERVICE_PREFIX_MAPPING can contain multiple DB backend definitions, separated by ",". Process them all
    IFS=',' read -a db_backends <<< "$DB_SERVICE_PREFIX_MAPPING"

    for db_backend in ${db_backends[@]}; do
      local service_name=${db_backend%=*}
      local service=${service_name^^}
      service=${service//-/_}
      local db=${service##*_}
      local prefix=${db_backend#*=}

      declare -A DB_CONNECTION_PROPERTIES=( ['ServerName']="${service}_SERVICE_HOST" ['PortNumber']="${service}_SERVICE_PORT" ['DatabaseName']="${prefix}_DATABASE" )
      # Derive DB server name & port from automatic OpenShift variables, created for each service
      # Derive DB server database name from the "${prefix}_DATABASE" environment variable
      for key in "${!DB_CONNECTION_PROPERTIES[@]}"; do
        value="${DB_CONNECTION_PROPERTIES[$key]}"
        # Use indirect variable reference to obtain the real value of a particular environment variable (e.g. 'SSO_MYSQL_SERVICE_HOST') passed to the RH-SSO pod
        DB_CONNECTION_PROPERTIES["$key"]="${!value}"
      done

      # Set XA connection properties (DB server name, port number & database name) to avoid WFLYJCA0069 error
      # Thus assign those indirect reference variable values (current values of DB_CONNECTION_PROPERTIES hash)
      # to newly created environment variable with a proper ${prefix}_XA_CONNECTION_PROPERTY_* name
      printf -v "${prefix}_XA_CONNECTION_PROPERTY_ServerName" '%s' "${DB_CONNECTION_PROPERTIES['ServerName']}"
      printf -v "${prefix}_XA_CONNECTION_PROPERTY_PortNumber" '%s' "${DB_CONNECTION_PROPERTIES['PortNumber']}"
      printf -v "${prefix}_XA_CONNECTION_PROPERTY_DatabaseName" '%s' "${DB_CONNECTION_PROPERTIES['DatabaseName']}"

      # Set also the ${prefix}_DRIVER variable so the datasource is created
      printf -v "${prefix}_DRIVER" '%s' "${db,,}"

    done

  fi

  inject_datasources
}

function configureEnv() {
  inject_external_datasources
}

function inject_datasources() {
  inject_datasources_common

  inject_default_job_repositories
}

function generate_datasource() {
  local pool_name="${1}"
  local jndi_name="${2}"
  local username="${3}"
  local password="${4}"
  local host="${5}"
  local port="${6}"
  local databasename="${7}"
  local checker="${8}"
  local sorter="${9}"
  local driver="${10}"
  local service_name="${11}"
  local jta="${12}"
  local validate="${13}"
  local url="${14}"

  generate_datasource_common "${1}" "${2}" "${3}" "${4}" "${5}" "${6}" "${7}" "${8}" "${9}" "${driver}" "${11}" "${12}" "${13}" "${14}"

  if [ -z "$service_name" ]; then
    service_name="ExampleDS"
    pool_name="ExampleDS"
    if [ -n "$DB_POOL" ]; then
      pool_name="$DB_POOL"
    fi
  fi

  if [ -n "$DEFAULT_JOB_REPOSITORY" -a "$DEFAULT_JOB_REPOSITORY" = "${service_name}" ]; then
    inject_default_job_repository $pool_name
    inject_job_repository $pool_name
  fi

  if [ -z "$DEFAULT_JOB_REPOSITORY" ]; then
    inject_default_job_repository in-memory
  fi

}

# $1 - refresh-interval
function refresh_interval() {
    echo "refresh-interval=\"$1\""
}

function inject_default_job_repositories() {
  defaultjobrepo="     <default-job-repository name=\"in-memory\"/>"

  sed -i "s|<!-- ##DEFAULT_JOB_REPOSITORY## -->|${defaultjobrepo%$'\n'}|g" $CONFIG_FILE
}

# Arguments:
# $1 - default job repository name
function inject_default_job_repository() {
  defaultjobrepo="     <default-job-repository name=\"${1}\"/>"

  sed -i "s|<!-- ##DEFAULT_JOB_REPOSITORY## -->|${defaultjobrepo%$'\n'}|" $CONFIG_FILE
}

function inject_job_repository() {
  jobrepo="     <job-repository name=\"${1}\">\
      <jdbc data-source=\"${1}\"/>\
    </job-repository>\
    <!-- ##JOB_REPOSITORY## -->"

  sed -i "s|<!-- ##JOB_REPOSITORY## -->|${jobrepo%$'\n'}|" $CONFIG_FILE
}
