#!/bin/bash

mavenRepo="$1"
if [ -f "$mavenRepo/patches.xml" ]; then
  echo "The maven repository has been patched, setting patches in galleon feature-pack."
  patches=`cat "$mavenRepo/patches.xml" | sed ':a;N;$!ba;s/\n//g'`
  # CIAM-1394 correction
  sed -i "s${AUS}<!-- ##PATCHES## -->${AUS}$patches${AUS}" "${GALLEON_FP_PATH}/wildfly-user-feature-pack-build.xml"
  # EOF CIAM-1394 correction
  echo "wildfly-user-feature-pack-build.xml content:"
  cat "${GALLEON_FP_PATH}/wildfly-user-feature-pack-build.xml"
fi
