
# Override the definition of the generate_external_datasource() routine from the
# JBoss EAP 'os-eap-datasource' v1.0 module to add support for MariaDB driver

function generate_external_datasource() {
  local failed="false"

  if [ -n "$NON_XA_DATASOURCE" ] && [ "$NON_XA_DATASOURCE" = "true" ]; then
    ds="<datasource jta=\"${jta}\" jndi-name=\"${jndi_name}\" pool-name=\"${pool_name}\" enabled=\"true\" use-java-context=\"true\" statistics-enabled=\"\${wildfly.datasources.statistics-enabled:\${wildfly.statistics-enabled:false}}\">
          <connection-url>${url}</connection-url>
          <driver>$driver</driver>"
  else
    ds=" <xa-datasource jndi-name=\"${jndi_name}\" pool-name=\"${pool_name}\" enabled=\"true\" use-java-context=\"true\" statistics-enabled=\"\${wildfly.datasources.statistics-enabled:\${wildfly.statistics-enabled:false}}\">"
    local xa_props=$(compgen -v | grep -s "${prefix}_XA_CONNECTION_PROPERTY_")
    # KEYCLOAK-10694 - Since previous RHEL-7 mysql-connector-java RPM was in RHEL-8 replaced with mariadb-java-client RPM, only drivers for MariaDB and
    # PostgreSQL databases are installed by default. Any other driver needs to be installed using EAP Runtime Artifacts Datasources mechanism
    if [ "$driver" != "mariadb" ] && [ "$driver" != "postgresql" ]; then
      log_warning "Only datasource drivers for the MariaDB and PostgreSQL databases are available in the image by default. Datasource will not be configured. Please use the JBoss EAP Runtime Artifacts Datasources mechanism: https://access.redhat.com/documentation/en-us/red_hat_jboss_enterprise_application_platform/7.2/html-single/getting_started_with_jboss_eap_for_openshift_container_platform/index#Runtime-Artifacts to configure the ${driver} JDBC driver."
      failed="true"
    fi

    if [ -z "$xa_props" ]; then
      log_warning "At least one ${prefix}_XA_CONNECTION_PROPERTY_property for datasource ${service_name} is required. Datasource will not be configured."
      failed="true"
    else

      for xa_prop in $(echo $xa_props); do
        prop_name=$(echo "${xa_prop}" | sed -e "s/${prefix}_XA_CONNECTION_PROPERTY_//g")
        prop_val=$(find_env $xa_prop)
        if [ ! -z ${prop_val} ]; then
          ds="$ds <xa-datasource-property name=\"${prop_name}\">${prop_val}</xa-datasource-property>"
        fi
      done

      ds="$ds
             <driver>${driver}</driver>"
    fi

    if [ -n "$tx_isolation" ]; then
      ds="$ds
             <transaction-isolation>$tx_isolation</transaction-isolation>"
    fi
  fi

  if [ -n "$min_pool_size" ] || [ -n "$max_pool_size" ]; then
    if [ -n "$NON_XA_DATASOURCE" ] && [ "$NON_XA_DATASOURCE" = "true" ]; then
       ds="$ds
             <pool>"
    else
      ds="$ds
             <xa-pool>"
    fi

    if [ -n "$min_pool_size" ]; then
      ds="$ds
             <min-pool-size>$min_pool_size</min-pool-size>"
    fi
    if [ -n "$max_pool_size" ]; then
      ds="$ds
             <max-pool-size>$max_pool_size</max-pool-size>"
    fi
    if [ -n "$NON_XA_DATASOURCE" ] && [ "$NON_XA_DATASOURCE" = "true" ]; then
      ds="$ds
             </pool>"
    else
      ds="$ds
             </xa-pool>"
    fi
  fi

   ds="$ds
         <security>
           <user-name>${username}</user-name>
           <password>${password}</password>
         </security>"

  if [ "$validate" == "true" ]; then

    validation_conf="<validate-on-match>true</validate-on-match>
                       <background-validation>false</background-validation>"

    if [ $(find_env "${prefix}_BACKGROUND_VALIDATION" "false") == "true" ]; then

        millis=$(find_env "${prefix}_BACKGROUND_VALIDATION_MILLIS" 10000)
        validation_conf="<validate-on-match>false</validate-on-match>
                           <background-validation>true</background-validation>
                           <background-validation-millis>${millis}</background-validation-millis>"
    fi

    ds="$ds
           <validation>
             ${validation_conf}
             <valid-connection-checker class-name=\"${checker}\"></valid-connection-checker>
             <exception-sorter class-name=\"${sorter}\"></exception-sorter>
           </validation>"
  fi

  if [ -n "$NON_XA_DATASOURCE" ] && [ "$NON_XA_DATASOURCE" = "true" ]; then
    ds="$ds
           </datasource>"
  else
    ds="$ds
           </xa-datasource>"
  fi

  if [ "$failed" == "true" ]; then
    echo ""
  else
    echo $ds
  fi
}

# Override the definition of the inject_tx_datasource() routine from the
# JBoss EAP 'os-eap7-launch' v1.0 module to add support for the MariaDB driver

function inject_tx_datasource() {
  tx_backend=${TX_DATABASE_PREFIX_MAPPING}

  if [ -n "${tx_backend}" ] ; then
    service_name=${tx_backend%=*}
    service=${service_name^^}
    service=${service//-/_}
    db=${service##*_}
    prefix=${tx_backend#*=}

    host=$(find_env "${service}_SERVICE_HOST")
    port=$(find_env "${service}_SERVICE_PORT")

    if [ -z $host ] || [ -z $port ]; then
      log_warning "There is a problem with your service configuration!"
      log_warning "You provided following database mapping (via TX_SERVICE_PREFIX_MAPPING environment variable): $tx_backend. To configure datasources we expect ${service}_SERVICE_HOST and ${service}_SERVICE_PORT to be set."
      log_warning
      log_warning "Current values:"
      log_warning
      log_warning "${service}_SERVICE_HOST: $host"
      log_warning " ${service}_SERVICE_PORT: $port"
      log_warning
      log_warning "Please make sure you provided correct service name and prefix in the mapping. Additionally please check that you do not set portalIP to None in the $service_name service. Headless services are not supported at this time."
      log_warning
      log_warning "The ${db,,} datasource for $prefix service WILL NOT be configured."
      return
    fi

    # Custom JNDI environment variable name format: [NAME]_[DATABASE_TYPE]_JNDI appended by ObjectStore
    jndi=$(find_env "${prefix}_JNDI" "java:jboss/datasources/${service,,}")

    # Database username environment variable name format: [NAME]_[DATABASE_TYPE]_USERNAME
    username=$(find_env "${prefix}_USERNAME")

    # Database password environment variable name format: [NAME]_[DATABASE_TYPE]_PASSWORD
    password=$(find_env "${prefix}_PASSWORD")

    # Database name environment variable name format: [NAME]_[DATABASE_TYPE]_DATABASE
    database=$(find_env "${prefix}_DATABASE")

    if [ -z $jndi ] || [ -z $username ] || [ -z $password ] || [ -z $database ]; then
      log_warning "Ooops, there is a problem with the ${db,,} datasource!"
      log_warning "In order to configure ${db,,} transactional datasource for $prefix service you need to provide following environment variables: ${prefix}_USERNAME, ${prefix}_PASSWORD, ${prefix}_DATABASE."
      log_warning
      log_warning "Current values:"
      log_warning
      log_warning "${prefix}_USERNAME: $username"
      log_warning "${prefix}_PASSWORD: $password"
      log_warning "${prefix}_DATABASE: $database"
      log_warning
      log_warning "The ${db,,} datasource for $prefix service WILL NOT be configured."
      db="ignore"
    fi

    # Transaction isolation level environment variable name format: [NAME]_[DATABASE_TYPE]_TX_ISOLATION
    tx_isolation=$(find_env "${prefix}_TX_ISOLATION")

    # min pool size environment variable name format: [NAME]_[DATABASE_TYPE]_MIN_POOL_SIZE
    min_pool_size=$(find_env "${prefix}_MIN_POOL_SIZE")

    # max pool size environment variable name format: [NAME]_[DATABASE_TYPE]_MAX_POOL_SIZE
    max_pool_size=$(find_env "${prefix}_MAX_POOL_SIZE")

    case "$db" in
      "MARIADB"|"MYSQL")
        # KEYCLOAK-10694 - Replace any request for MySQL DB driver with a request for MariaDB one in RHEL-8 UBI minimal
        driver="mariadb"
        service="${service//MYSQL/MARIADB}"
        datasource="$(generate_tx_datasource ${service,,} $jndi $username $password $host $port $database $driver)\n"
        inject_jdbc_store "${jndi}ObjectStore"
        ;;
      "POSTGRESQL")
        driver="postgresql"
        datasource="$(generate_tx_datasource ${service,,} $jndi $username $password $host $port $database $driver)\n"
        inject_jdbc_store "${jndi}ObjectStore"
        ;;
      *)
        datasource=""
        ;;
    esac
    echo ${datasource} | sed ':a;N;$!ba;s|\n|\\n|g'
  else
    if [ -n "$JDBC_STORE_JNDI_NAME" ]; then
      inject_jdbc_store "${JDBC_STORE_JNDI_NAME}"
    fi
  fi
}
