#!/bin/sh

function prepareEnv() {
  unset JBOSS_MODULES_SYSTEM_PKGS_APPEND
}

function configure() {
  configure_jboss_modules_system_pkgs
}

function configure_jboss_modules_system_pkgs() {
  if [ -z "$JBOSS_MODULES_SYSTEM_PKGS" ]; then
    export JBOSS_MODULES_SYSTEM_PKGS="jdk.nashorn.api,com.sun.crypto.provider"
  fi

  if [ -n "$JBOSS_MODULES_SYSTEM_PKGS_APPEND" ]; then
    JBOSS_MODULES_SYSTEM_PKGS="$JBOSS_MODULES_SYSTEM_PKGS,$JBOSS_MODULES_SYSTEM_PKGS_APPEND"
  fi
}