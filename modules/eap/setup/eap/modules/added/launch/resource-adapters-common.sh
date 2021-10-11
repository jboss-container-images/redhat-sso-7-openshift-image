#!/bin/sh

function clearResourceAdapterEnv() {
  local prefix=$1

  unset ${prefix}_ID
  unset ${prefix}_MODULE_SLOT
  unset ${prefix}_MODULE_ID
  unset ${prefix}_CONNECTION_CLASS
  unset ${prefix}_CONNECTION_JNDI
  unset ${prefix}_POOL_PREFILL
  unset ${prefix}_POOL_MAX_SIZE
  unset ${prefix}_POOL_MIN_SIZE
  unset ${prefix}_POOL_XA
  unset ${prefix}_POOL_IS_SAME_RM_OVERRIDE
  unset ${prefix}_POOL_FLUSH_STRATEGY
  unset ${prefix}_RECOVERY_USERNAME
  unset ${prefix}_RECOVERY_PASSWORD
  unset ${prefix}_ADMIN_OBJECTS
  unset ${prefix}_TRACKING

  for xa_prop in $(compgen -v | grep -s "${prefix}_PROPERTY_"); do
    unset ${xa_prop}
  done

  for admin_object in $(compgen -v | grep -s "${prefix}_ADMIN_OBJECT_"); do
    unset ${admin_object}
  done
}

function clearResourceAdaptersEnv() {
  for ra_prefix in $(echo $RESOURCE_ADAPTERS | sed "s/,/ /g"); do
    clearResourceAdapterEnv $ra_prefix
  done
  unset RESOURCE_ADAPTERS
}

function inject_resource_adapters_common() {
  local mode
  getConfigurationMode "<!-- ##RESOURCE_ADAPTERS## -->" "mode"

  resource_adapters=

  hostname=`hostname`

  for ra_prefix in $(echo $RESOURCE_ADAPTERS | sed "s/,/ /g"); do
    ra_id=$(find_env "${ra_prefix}_ID")
    if [ -z "$ra_id" ]; then
      log_warning "${ra_prefix}_ID is missing from resource adapter configuration, defaulting to ${ra_prefix}"
      ra_id="${ra_prefix}"
    fi

    ra_module_slot=$(find_env "${ra_prefix}_MODULE_SLOT")
    if [ -z "$ra_module_slot" ]; then
      log_warning "${ra_prefix}_MODULE_SLOT is missing from resource adapter configuration, defaulting to main"
      ra_module_slot="main"
    fi

    ra_archive=$(find_env "${ra_prefix}_ARCHIVE")
    ra_module_id=$(find_env "${ra_prefix}_MODULE_ID")
    if [ -z "$ra_module_id" ] && [ -z "$ra_archive" ]; then
      log_warning "${ra_prefix}_MODULE_ID and ${ra_prefix}_ARCHIVE are missing from resource adapter configuration. One is required. Resource adapter will not be configured"
      continue
    fi

    ra_class=$(find_env "${ra_prefix}_CONNECTION_CLASS")
    if [ -z "$ra_class" ]; then
      log_warning "${ra_prefix}_CONNECTION_CLASS is missing from resource adapter configuration. Resource adapter will not be configured"
      continue
    fi

    ra_jndi=$(find_env "${ra_prefix}_CONNECTION_JNDI")
    if [ -z "$ra_jndi" ]; then
      log_warning "${ra_prefix}_CONNECTION_JNDI is missing from resource adapter configuration. Resource adapter will not be configured"
      continue
    fi

    local resource_adapter=""

    create_resource_adapter "${mode}" "${ra_prefix}" "${ra_id}" "${ra_module_slot}" "${ra_archive}" "${ra_module_id}" "${ra_class}" "${ra_jndi}"

    resource_adapters="${resource_adapters}${resource_adapter}"
  done

  if [ -n "${resource_adapters}" ]; then
    resource_adapters=$(echo "${resource_adapters}" | sed -e "s/localhost/${hostname}/g")
    if [ "${mode}" = "xml" ]; then
      sed -i "s|<!-- ##RESOURCE_ADAPTERS## -->|${resource_adapters}<!-- ##RESOURCE_ADAPTERS## -->|" $CONFIG_FILE
    elif [ "${mode}" = "cli" ]; then
      echo "${resource_adapters}" >> ${CLI_SCRIPT_FILE}
    fi
  fi
}

function create_resource_adapter() {
    local mode="${1}"
    local ra_prefix="${2}"
    local ra_id="${3}"
    local ra_module_slot="${4}"
    local ra_archive="${5}"
    local ra_module_id="${6}"
    local ra_class="${7}"
    local ra_jndi="${8}"

    transaction_support=$(find_env "${ra_prefix}_TRANSACTION_SUPPORT")
    admin_object_list=$(find_env "${ra_prefix}_ADMIN_OBJECTS")

    if [ "${mode}" = "xml" ]; then

      # Defined in the calling function
      resource_adapter="<resource-adapter id=\"$ra_id\">"

      if [ -z "${ra_archive}" ]; then
        resource_adapter="${resource_adapter}<module slot=\"$ra_module_slot\" id=\"$ra_module_id\"></module>"
      else
        resource_adapter="${resource_adapter}<archive>$ra_archive</archive>"
      fi

      if [ -n "$transaction_support" ]; then
        resource_adapter="${resource_adapter}<transaction-support>$transaction_support</transaction-support>"
      fi

      add_connection_definitions "${mode}" "${ra_prefix}" ""


      if [ -n "$admin_object_list" ]; then
        admin_objects="$(add_admin_objects ${admin_object_list} ${mode})"
        if [ -n "$admin_objects" ]; then
          resource_adapter="${resource_adapter}<admin-objects>${admin_objects}</admin-objects>"
        fi
      fi

      resource_adapter="${resource_adapter}</resource-adapter>"
    elif [ "${mode}" = "cli" ]; then
      local subsystem_addr="/subsystem=resource-adapters"
      local ra_addr="${subsystem_addr}/resource-adapter=${ra_id}"
      resource_adapter="
        if (outcome != success) of ${subsystem_addr}:read-resource
          echo You have set environment variables to configure resource-adapters. Fix your configuration to contain the resource-adapters subsystem for this to happen. >> \${error_file}
          exit
        end-if

        if (outcome == success) of ${ra_addr}:read-resource
          echo You have set environment variables to configure the resource-adapter '${ra_id}'. However, your base configuration already contains a resource-adapter with that name. >> \${error_file}
          exit
        end-if

        batch
      "
      local ra_add="${ra_addr}:add("
      if [ -z "${ra_archive}" ]; then
        ra_add="${ra_add}module=\"${ra_module_id}:${ra_module_slot}\""
      else
        ra_add="${ra_add}archive=\"${ra_archive}\""
      fi

      if [ -n "$transaction_support" ]; then
        ra_add="${ra_add}, transaction-support=\"${transaction_support}\""
      fi
      ra_add="${ra_add})"

      resource_adapter="${resource_adapter}
        ${ra_add}
      "
      add_connection_definitions "${mode}" "${ra_prefix}" "${ra_addr}"
      if [ -n "$admin_object_list" ]; then
        admin_objects="$(add_admin_objects ${admin_object_list} ${mode} ${ra_addr})"
        if [ -n "$admin_objects" ]; then
          resource_adapter="${resource_adapter}
          ${admin_objects}"
        fi
      fi

      resource_adapter="${resource_adapter}
        run-batch
      "
    fi
}

function add_connection_definitions() {
    local mode="${1}"
    local ra_prefix="${2}"
    local ra_addr="${3}"

    tracking=$(find_env "${ra_prefix}_TRACKING")
    ra_props=$(compgen -v | grep -s "${ra_prefix}_PROPERTY_")
    ra_pool_min_size=$(find_env "${ra_prefix}_POOL_MIN_SIZE")
    ra_pool_max_size=$(find_env "${ra_prefix}_POOL_MAX_SIZE")
    ra_pool_prefill=$(find_env "${ra_prefix}_POOL_PREFILL")
    ra_pool_flush_strategy=$(find_env "${ra_prefix}_POOL_FLUSH_STRATEGY")
    ra_pool_is_same_rm_override=$(find_env "${ra_prefix}_POOL_IS_SAME_RM_OVERRIDE")
    recovery_username=$(find_env "${ra_prefix}_RECOVERY_USERNAME")
    recovery_password=$(find_env "${ra_prefix}_RECOVERY_PASSWORD")
    ra_pool_xa=$(find_env "${ra_prefix}_POOL_XA")

    if [ "${mode}" = "xml" ]; then
      resource_adapter="${resource_adapter}<connection-definitions><connection-definition"

      if [ -n "${tracking}" ]; then
        # monitor applications, look for unclosed resources.
        resource_adapter="${resource_adapter} tracking=\"${tracking}\""
      fi
      resource_adapter="${resource_adapter} class-name=\"${ra_class}\" jndi-name=\"${ra_jndi}\" enabled=\"true\" use-java-context=\"true\">"

      if [ -n "$ra_props" ]; then
        for ra_prop in $(echo $ra_props); do
          prop_name=$(echo "${ra_prop}" | sed -e "s/${ra_prefix}_PROPERTY_//g")
          prop_val=$(find_env $ra_prop)

          resource_adapter="${resource_adapter}<config-property name=\"${prop_name}\">${prop_val}</config-property>"
        done
      fi

      if [ -n "$ra_pool_min_size" ] || [ -n "$ra_pool_max_size" ] || [ -n "$ra_pool_prefill" ] || [ -n "$ra_pool_flush_strategy" ]; then
        if [ -n "$ra_pool_xa" ] && [ "$ra_pool_xa" == "true" ]; then
          resource_adapter="${resource_adapter}<xa-pool>"
        else
          resource_adapter="${resource_adapter}<pool>"
        fi

        if [ -n "$ra_pool_min_size" ]; then
          resource_adapter="${resource_adapter}<min-pool-size>${ra_pool_min_size}</min-pool-size>"
        fi

        if [ -n "$ra_pool_max_size" ]; then
          resource_adapter="${resource_adapter}<max-pool-size>${ra_pool_max_size}</max-pool-size>"
        fi

        if [ -n "$ra_pool_prefill" ]; then
          resource_adapter="${resource_adapter}<prefill>${ra_pool_prefill}</prefill>"
        fi

        if [ -n "$ra_pool_flush_strategy" ]; then
          resource_adapter="${resource_adapter}<flush-strategy>${ra_pool_flush_strategy}</flush-strategy>"
        fi

        if [ -n "$ra_pool_is_same_rm_override" ]; then
          resource_adapter="${resource_adapter}<is-same-rm-override>${ra_pool_is_same_rm_override}</is-same-rm-override>"
        fi

        if [ -n "$ra_pool_xa" ] && [ "$ra_pool_xa" == "true" ]; then
          resource_adapter="${resource_adapter}</xa-pool>"
        else
          resource_adapter="${resource_adapter}</pool>"
        fi
      fi

      if [ -n "$recovery_username" ] && [ -n "$recovery_password" ]; then
        resource_adapter="${resource_adapter}<recovery><recover-credential><user-name>$recovery_username</user-name><password>$recovery_password</password></recover-credential></recovery>"
      fi

      resource_adapter="${resource_adapter}</connection-definition></connection-definitions>"
    elif [ "${mode}" = "cli" ]; then
      # We need to work out the pool-name from the jndi-name (same as the WildFly ResourceAdapters parser does)
      local pool_name
      if [[ "${ra_jndi}" == *\/* ]]; then
        pool_name="$(echo ${ra_jndi}|sed 's/.*\///')"
      else
        pool_name="$(echo ${ra_jndi}|sed 's/.*://')"
      fi

      conn_def_addr="${ra_addr}/connection-definitions=${pool_name}"
      conn_def_add="${conn_def_addr}:add(class-name=\"${ra_class}\", jndi-name=\"${ra_jndi}\", enabled=\"true\", use-java-context=\"true\""

      local xpathSec="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:jboss:domain:security:')]\""
      local secRet
      testXpathExpression "${xpathSec}" "secRet"
      local xpathEl="\"//*[local-name()='subsystem' and starts-with(namespace-uri(), 'urn:wildfly:elytron:')]\""
      local elytronRet
      testXpathExpression "${xpathEl}" "elytronRet"

      # no legacy security case
      if [ "${secRet}" -ne 0 ]; then
        if [ "${elytronRet}" -ne 0 ]; then
          echo "Elytron subsystem is not present. resource-adapter connection-definition can't be added. Fix your configuration." >> "${CONFIG_ERROR_FILE}"
          exit 1
        fi
        conn_def_add="${conn_def_add}, elytron-enabled=true, recovery-elytron-enabled=true"
      fi

      if [ -n "${tracking}" ]; then
        # monitor applications, look for unclosed resources.
        conn_def_add="${conn_def_add}, tracking=\"${tracking}\""
      fi

      if [ -n "$ra_pool_min_size" ] || [ -n "$ra_pool_max_size" ] || [ -n "$ra_pool_prefill" ] || [ -n "$ra_pool_flush_strategy" ]; then
        # Whether the pool is written out again as an xa-pool depends on if the RA has transaction-support=="XATransaction"
        # from the model point of view $pool_xa which for the xml case chooses between <pool> and <xa-pool> seems to have no effect

        if [ -n "$ra_pool_min_size" ]; then
          conn_def_add="${conn_def_add}, min-pool-size=${ra_pool_min_size}"
        fi

        if [ -n "$ra_pool_max_size" ]; then
          conn_def_add="${conn_def_add}, max-pool-size=${ra_pool_max_size}"
        fi

        if [ -n "$ra_pool_prefill" ]; then
          conn_def_add="${conn_def_add}, pool-prefill=${ra_pool_prefill}"
        fi

        if [ -n "$ra_pool_flush_strategy" ]; then
          conn_def_add="${conn_def_add}, flush-strategy=${ra_pool_flush_strategy}"
        fi

        if [ -n "$ra_pool_is_same_rm_override" ]; then
          conn_def_add="${conn_def_add}, same-rm-override=${ra_pool_is_same_rm_override}"
        fi
      fi

      if [ -n "$recovery_username" ] && [ -n "$recovery_password" ]; then
        conn_def_add="${conn_def_add}, recovery-username=\"${recovery_username}\", recovery-password=\"${recovery_password}\""
      fi

      conn_def_add="${conn_def_add})"
      resource_adapter="${resource_adapter}
        ${conn_def_add}
      "

      if [ -n "$ra_props" ]; then
        for ra_prop in $(echo $ra_props); do
          prop_name=$(echo "${ra_prop}" | sed -e "s/${ra_prefix}_PROPERTY_//g")
          prop_val=$(find_env $ra_prop)
          resource_adapter="${resource_adapter}
            ${conn_def_addr}/config-properties=${prop_name}:add(value=\"${prop_val}\")
          "
        done
      fi
    fi

}


function add_admin_objects() {
  admin_object_list="$1"
  mode="${2}"
  ra_addr="$3"

  admin_objects=
  IFS=',' read -a objects <<< ${admin_object_list}
  if [ "${#objects[@]}" -ne "0" ]; then
    for object in "${objects[@]}"; do
      class_name=$(find_env "${ra_prefix}_ADMIN_OBJECT_${object}_CLASS_NAME")
      physical_name=$(find_env "${ra_prefix}_ADMIN_OBJECT_${object}_PHYSICAL_NAME")
      if [ -n "$class_name" ] && [ -n "$physical_name" ]; then
        if [ "${mode}" = "xml" ]; then
          admin_objects="${admin_objects}<admin-object class-name=\"$class_name\" jndi-name=\"java:/${physical_name}\" use-java-context=\"true\" pool-name=\"${physical_name}\"><config-property name=\"PhysicalName\">${physical_name}</config-property></admin-object>"
        elif [ "${mode}" = "cli" ]; then
          admin_objects="${admin_objects}
            ${ra_addr}/admin-objects=\"${physical_name}\":add(class-name=\"$class_name\", jndi-name=\"java:/${physical_name}\", use-java-context=true)
            ${ra_addr}/admin-objects=\"${physical_name}\"/config-properties=PhysicalName:add(value=\"${physical_name}\")
          "
        fi
      else
        log_warning "Cannot configure admin-object $object for resource adapter $ra_prefix. Missing ${ra_prefix}_ADMIN_OBJECT_${object}_CLASS_NAME and/or ${ra_prefix}_ADMIN_OBJECT_${object}_PHYSICAL_NAME"
      fi
    done
  fi

  echo "$admin_objects"
}