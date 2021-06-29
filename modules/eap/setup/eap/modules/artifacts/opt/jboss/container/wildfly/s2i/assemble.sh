#!/bin/sh

set -e

function copy_server_s2i_output() {
  isSlim="$(galleon_is_slim_server)"
  if [ "$isSlim" != "true" ]; then
    if [ "x$S2I_COPY_SERVER" == "xtrue" ]; then
      mkdir -p $WILDFLY_S2I_OUTPUT_DIR
      log_info "Copying server to $WILDFLY_S2I_OUTPUT_DIR"
      cp -r -L $JBOSS_HOME $WILDFLY_S2I_OUTPUT_DIR/server
      rm -rf $JBOSS_HOME
      rm -rf /deployments/*
      log_info "Linking $JBOSS_HOME to $WILDFLY_S2I_OUTPUT_DIR"
      ln -s $WILDFLY_S2I_OUTPUT_DIR/server $JBOSS_HOME
    fi
  else
    if [ "x$S2I_COPY_SERVER" == "xtrue" ]; then
      log_info "Server not copied to $WILDFLY_S2I_OUTPUT_DIR, provisioned server is bound to local repository and can't be used in chained build. You can use galleon env variables to provision a server that can then be used in chained build."
    fi
  fi
}

source "${JBOSS_CONTAINER_UTIL_LOGGING_MODULE}/logging.sh"
source "${JBOSS_CONTAINER_MAVEN_S2I_MODULE}/maven-s2i"

# include our overrides/extensions
source "${JBOSS_CONTAINER_WILDFLY_S2I_MODULE}/s2i-core-hooks"

# Galleon integration
source "${JBOSS_CONTAINER_WILDFLY_S2I_MODULE}/galleon/s2i_galleon"

galleon_provision_server

# invoke the build
maven_s2i_build

copy_server_s2i_output

galleon_cleanup
