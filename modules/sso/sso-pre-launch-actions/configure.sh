#!/bin/bash
set -eu

# Import RH-SSO global variables & functions to image build-time
# shellcheck disable=SC1091
source "${JBOSS_HOME}/bin/launch/sso-rcfile-definitions.sh"

# CIAM-2404 Ensure using the latest versions of RPM packages by calling microdnf update
microdnf update -y

# CIAM-1757: On each arch remove JDK 1.8 rpms if present (since using JDK 11 already)
rpm --query --all name=java* version=1.8.0* | xargs rpm -e --nodeps

# RHSSO-2346 To support dual-stack OpenShift clusters, strictly enforce the value of
# "java.net.preferIPv4Stack" property is reset back to its default value of "false" as per
# https://docs.oracle.com/en/java/javase/11/docs/api/java.base/java/net/doc-files/net-properties.html
# across all the *.conf, *.conf.bat, and *.conf.ps1 files, present in the $JBOSS_HOME/bin directory
#
# Note:
# The asterisk '*' character in the following sed statement was intentionally left outside of the
# enclosing double-quotes to achieve proper Bash globbing prior the actual execution of the statement
sed -i 's/\(-Djava.net.preferIPv4Stack\)=true/\1=false/g' "${JBOSS_HOME}"/bin/*.conf{,.bat,.ps1}
