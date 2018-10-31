# Arquillian Tests for Red Hat Single-Sign On (SSO)

This project contains OpenShift v3 tests for the Red Hat SSO/Keycloak image and the SSO/Keycloak capabilities of the EAP image

## Requirements

The following are required to run the tests:

* Maven 3+
* OpenShift environment
* Available `oc` command
* You should use DNS server that is able to resolve domains used/create by OpenShift environment

## Usage

Before you can execute tests you need to gather some required information, which is:

* User token used to authenticate against OpenShift
* Router IP is the IP of the hosts where OpenShift router is deployed
* OpenShift URL is the hostname and port combination of the API endpoint
* Route suffix is the domain name that will be used and


```
# Log in into OpenShift
oc login OPENSHIFT_URL:OPENSHIFT_PORT -u OPENSHIFT_USER -p OPENSHIFT_PASSWORD

# Retrieve token
TOKEN=$(oc whoami -t)
```

Now you can run the tests

```
mvn clean install -Dkubernetes.master=https://${OPENSHIFT_URL}:${OPENSHIFT_PORT} -Dkubernetes.auth.token=${TOKEN} -Drouter.hostIP=${ROUTER_IP} -Darquillian.startup.timeout=6000
```

Additionally you can (or even should) specify which images should be used to run the tests against by specifying additional parameters:

* `-DimageStream.sso72.image` - full name of the SSO 7.2 image
* `-DimageStream.eap71.image` - full name of the EAP 7.1 image
* `-DimageStream.eap64.image` - full name of the EAP 6.4 image
