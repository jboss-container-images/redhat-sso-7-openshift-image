# Configure Logger Category
#
# Usage:
#   It will look for a environment variable called LOGGER_CATEGORIES
#   It will expect for new loggers in the following patter: logger-category:logger-level,second-logger-category:level
#       Example: LOGGER_CATEGORIES=com.my.package:TRACE, com.my.other.package:TRACE
#
#   The script will output the following format and add it to the standalone-openshift.xml file,
#   for the example above we'll have:
#
#            <logger category="com.my.package">
#                <level name="TRACE"/>
#            </logger>
#            <logger category="com.my.other.package">
#                <level name="TRACE"/>
#            </logger>

source $JBOSS_HOME/bin/launch/logging.sh

prepareEnv() {
  unset LOGGER_CATEGORIES
}

configure() {
  add_logger_category
}

add_logger_category() {
    # JUL implementation: https://docs.oracle.com/javase/7/docs/api/java/util/logging/Level.html
    # Plus JBoss logging levels
    local allowed_log_levels=("ALL" "SEVERE" "ERROR" "WARNING" "INFO" "CONFIG" "FINE" "DEBUG" "FINER" "FINEST" "TRACE")

    local IFS=","
    if [ "x${LOGGER_CATEGORIES}" != "x" ] && grep -q '<!-- ##LOGGER-CATEGORY## -->' ${CONFIG_FILE}; then
        log_info "Found env LOGGER_CATEGORIES, configuring...."
        for i in ${LOGGER_CATEGORIES}; do
            logger=$(echo "$i" | sed 's/ //g')
            logger_category=$(echo $logger | awk -F':' '{print $1}')
            logger_level=$(echo $logger | awk -F':' '{print $2}')
            if [[ ! "${allowed_log_levels[@]}" =~ " ${logger_level}" ]]; then
                 log_warning "Log Level ${logger_level} is not allowed, the allowed levels are ${allowed_log_levels[@]}"
            else
                log_info "Configuring logger category ${logger_category} with level ${logger_level:-FINE}"
                logger="<logger category=\"${logger_category}\">\n                \
<level name=\"${logger_level:-FINE}\"/>\n\            \
</logger>\n            \
<!-- ##LOGGER-CATEGORY## -->"
                sed -i "s|<!-- ##LOGGER-CATEGORY## -->|${logger}|" $CONFIG_FILE
            fi
        done
    fi
}