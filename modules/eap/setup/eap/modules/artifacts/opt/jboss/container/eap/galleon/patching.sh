#!/bin/bash

# RHSSO-2211 Import common RH-SSO global variables & functions
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

mavenRepo="$1"
if [ -f "$mavenRepo/patches.xml" ]; then
  echo "The maven repository has been patched, setting patches in galleon feature-pack."
  patches=`cat "$mavenRepo/patches.xml" | sed ':a;N;$!ba;s/\n//g'`
  # RHSSO-2017 Escape possible ampersand and semicolong characters
  # which are interpolated when used in sed righ-hand side expression
  patches=$(escape_sed_rhs_interpolated_characters "${patches}")
  # EOF RHSSO-2017 correction
  # CIAM-1394 correction
  sed -i "s${AUS}<!-- ##PATCHES## -->${AUS}$patches${AUS}" "${GALLEON_FP_PATH}/wildfly-user-feature-pack-build.xml"
  # EOF CIAM-1394 correction
  echo "wildfly-user-feature-pack-build.xml content:"
  cat "${GALLEON_FP_PATH}/wildfly-user-feature-pack-build.xml"
fi
