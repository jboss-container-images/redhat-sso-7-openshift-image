#!/bin/bash

#  Note: This module can be removed altogether once Red Hat Single Sign-On 7
#        OpenShift container images don't need to support OpenShift v3.x.
#
#        Starting from OpenShift v4.2 onward the CRI-O OpenShift run-time engine
#        inserts the random user for the container into /etc/passwd:
#        * https://access.redhat.com/articles/4859371
#        * https://github.com/cri-o/cri-o/pull/2022/commits/77408ef1490002e62c88baacc5c994e97aa793c6
#
#        which avoids the need to perform additional custom modification on
#        per image basis to achieve image support for arbitrary user IDs.

function configure() {
  configure_nss_wrapper_passwd
}

function configure_nss_wrapper_passwd() {
  # KEYCLOAK-17694 Since the user ID of the container running on OpenShift
  # is generated dynamically, in the passwd file utilized by nss_wrapper change
  # the user ID of the 'jboss' user to the actual user ID the container is being
  # run with so username mapping works properly in this case too
  sed "/^jboss/s/[^:]*/$(id -u)/3" "${NSS_WRAPPER_PASSWD}" > /tmp/passwd
  cat /tmp/passwd > "${NSS_WRAPPER_PASSWD}"
  rm /tmp/passwd
}
