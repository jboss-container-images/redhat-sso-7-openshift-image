# SSL/TLS support for PostgreSQL SQL database server container image

The [PostgreSQL 10 SQL database server](https://catalog.redhat.com/software/containers/rhscl/postgresql-10-rhel7/5aa63541ac3db95f196086f1)
doesn't support SSL/TLS encryption by default. In order to enable the
SSL/TLS encryption, the PostgreSQL server container image needs to be
extended using the [source-to-image](https://github.com/openshift/source-to-image)
method. Refer to [_*Extending image*_](https://catalog.redhat.com/software/containers/rhscl/postgresql-10-rhel7/5aa63541ac3db95f196086f1)
and primarily to [the available example](https://github.com/sclorg/postgresql-container/tree/master/examples/enable-ssl)
for additional details.

This (sub)directory contains all the information needed to enable SSL/TLS
support for the [PostgreSQL 10 SQL database server](https://catalog.redhat.com/software/containers/rhscl/postgresql-10-rhel7/5aa63541ac3db95f196086f1)
used in the available PostgreSQL [templates](https://github.com/jboss-container-images/redhat-sso-7-openshift-image/tree/sso75-dev/templates)
for [Red Hat Single Sign-On 7.5 for OpenJDK / OpenJ9 on OpenShift container images](https://github.com/jboss-container-images/redhat-sso-7-openshift-image/tree/sso75-dev).
