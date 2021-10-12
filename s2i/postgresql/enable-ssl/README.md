# Example to enable SSL/TLS for the PostgreSQL SQL database server container image

Inspired by the ["enable-ssl"](https://github.com/sclorg/postgresql-container/tree/master/examples/enable-ssl)
example from the Red Hat Software Collections PostgreSQL container images repository.

Compared to the original, this example does NOT store the TLS certificate & private
key files directly in the repository. Instead of that, those files are generated
on the fly by the PostgreSQL OpenShift service using the OpenShift's service serving
certificate secrets mechanism based on the corresponding annotation applied to the
definition of the PostgreSQL service.
