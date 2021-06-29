## Keycloak integration bats tests

These bats tests verify the `keycloak.sh` script use cases.

### The Mock Server

The [`server`](server) dir has a bash utility called [shinatra](https://github.com/benrady/shinatra) to mock a real web server for use cases that require Kubernetes API integration.

The JSON mock responses to test the API calls are in the [`mock_responses`](mock_responses) directory.

To create a new test case, just create a new JSON file from the API you want to test and save it in the `mock_responses` directory. Check the [OpenShift API reference](https://docs.openshift.com/container-platform/3.11/rest_api/) if you are not sure how to call the internal APIs.

Then you can use the [`setup_k8s_api`](common.bash) to fire up the server. Just don't forget to kill the pid and all the child processes. Check the usage of this function in the test suite [`hostname-discovery.bats`](hostname-discovery.bats).

### Hostname Discovery Test Suite

The tests cases in the [`hostname-discovery.bats`](hostname-discovery.bats) file basically verify if the function `query_routes_from_service` on `keycloak.sh` is working as expected simulating scenarios where the API is not available, there's one, multiple or no routes at all.