#!/bin/bash

mavenRepo="$1"
if [ -f "$mavenRepo/patches.xml" ]; then
  echo "The maven repository has been patched, setting patches in galleon feature-pack."
  patches=`cat "$mavenRepo/patches.xml" | sed ':a;N;$!ba;s/\n//g'`
  sed -i "s|<!-- ##PATCHES## -->|$patches|" "${GALLEON_FP_PATH}/wildfly-user-feature-pack-build.xml"
  echo "wildfly-user-feature-pack-build.xml content:"
  cat "${GALLEON_FP_PATH}/wildfly-user-feature-pack-build.xml"
fi