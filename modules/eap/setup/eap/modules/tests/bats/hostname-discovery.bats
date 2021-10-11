#!/usr/bin/env bats

load common

# Runs the base api test
# {1} mock_response
function run_api_test {
    local mock_response=${1}
    local server_pid=$(setup_k8s_api ${mock_response})
    K8S_ENV=true
    APPLICATION_ROUTES=""
    get_application_routes
    local routes=${APPLICATION_ROUTES}
    echo "Routes are ${routes}" >&2
    pkill -P $server_pid
    echo $routes
}

@test "Is netcat installed?" {
  if [ -f /bin/nc ] || [ -f /usr/bin/nc ]; then
     result="ok"
  else
     result="failed"
  fi
  [ "${result}" = "ok" ]
}

@test "Kubernetes Route API not available" {
    local expected=""
    if [ "$K8S_ENV" = true ]; then
      skip "This test supposed to be run outside a kubernetes environment"
    fi
    run discover_routes
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "${expected}" ]
}

@test "Kubernetes Route API found no routes for the pod" {
    local expected=""
    local mock_response="no-route"
    result=$(run_api_test $mock_response)
    [ "${result}" = "$expected" ]
}

@test "Kubernetes Route API found one route for the pod" {
    local expected="https://eap-app-bsig-cloud.192.168.99.100.nip.io;https://eap-app-bsig-cloud.192.168.99.100.nip.io:443"
    local mock_response="single-route"
    result=$(run_api_test $mock_response)
    [ "${result}" = "$expected" ]
}

@test "Kubernetes Route API found multiple routes for the pod" {
    local expected="http://bc-authoring-rhpamcentr-bsig-cloud.192.168.99.100.nip.io;http://bc-authoring-rhpamcentr-bsig-cloud.192.168.99.100.nip.io:80;https://secure-bc-authoring-rhpamcentr-bsig-cloud.192.168.99.100.nip.io;https://secure-bc-authoring-rhpamcentr-bsig-cloud.192.168.99.100.nip.io:443"
    local mock_response="multi-route"
    result=$(run_api_test $mock_response)
    [ "${result}" = "$expected" ]
}


@test "default port has been added to one single route without port" {
    local expected="http://localhost;http://localhost:80"
    result=$(add_route_with_default_port "http://localhost")
    echo "Expected is '${expected}', but result: '${result}'" >&2
    [ "${result}" = "$expected" ]
}

@test "default ports has NOT been added to routes with ports" {
    local expected="http://localhost:80"
    result=$(add_route_with_default_port "http://localhost:80")
    echo "Expected is '${expected}', but result: '${result}'" >&2
    [ "${result}" = "$expected" ]
}

@test "default ports been added to routes without ports" {
    local expected="http://localhost;http://localhost:80;https://localhost;https://localhost:443"
    result=$(add_route_with_default_port "http://localhost;https://localhost")
    echo "Expected is '${expected}', but result: '${result}'" >&2
    [ "${result}" = "$expected" ]
}

@test "blank routes have no ports at all." {
    local expected=""
    result=$(add_route_with_default_port "")
    echo "Expected is '${expected}', but result: '${result}'" >&2
    [ "${result}" = "$expected" ]
} 
