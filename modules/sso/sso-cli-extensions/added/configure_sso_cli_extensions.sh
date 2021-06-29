#!/bin/sh

function postConfigure() {
  if [ -f "${JBOSS_HOME}/extensions/sso-extensions.cli" ]; then
    (
      echo "embed-server --std-out=echo  --server-config=standalone-openshift.xml" ;
      cat "${JBOSS_HOME}/extensions/sso-extensions.cli" ; 
      echo -e '\nquit\n'
    ) | $JBOSS_HOME/bin/jboss-cli.sh
  fi
}
