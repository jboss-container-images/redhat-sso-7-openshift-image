echo $BATS_TEST_DIRNAME
load $BATS_TEST_DIRNAME/../../../../../../../test-common/log_utils.bash

export JBOSS_HOME=$BATS_TMPDIR/jboss_home
export K8S_ENV=false
export KUBERNETES_SERVICE_HOST="localhost"
export KUBERNETES_SERVICE_PORT=8080
export KUBERNETES_SERVICE_PROTOCOL="http"

if [ -e /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
  K8S_ENV=true
fi

mkdir -p $JBOSS_HOME/bin/launch
mkdir -p $JBOSS_HOME/responses
cp $BATS_TEST_DIRNAME/../../added/keycloak.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../../../../../test-common/logging.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/server/shinatra.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/mock_responses/* $JBOSS_HOME/responses

source $JBOSS_HOME/bin/launch/keycloak.sh
source $JBOSS_HOME/bin/launch/shinatra.sh

# Configure the Mocked Kubernetes server based on mocked responses
# {1} mock_response
function setup_k8s_api() {
  local mock_response=${1}
  local data=$(cat $JBOSS_HOME/responses/${mock_response}.json | tr -d \\n)
  start_mock_server ${KUBERNETES_SERVICE_PORT} "${data}" >&2 &
  local pid=$!
  echo ${pid}
}