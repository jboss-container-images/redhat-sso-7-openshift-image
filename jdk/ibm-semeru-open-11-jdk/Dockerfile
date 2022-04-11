FROM registry.redhat.io/rh-sso-7/sso75-openshift-rhel8:latest
# Define the (buildtime) user
USER root
# Copy the helper container image script
COPY scripts/image /tmp/scripts
# Make IBM Semeru 11 JDK the default JDK
RUN [ "sh", "-x", "/tmp/scripts/make-ibm-semeru-open-11-jdk-the-default-jdk.sh" ]
# Remove helper scripts
RUN [ ! -d "/tmp/scripts" ] || rm -rf "/tmp/scripts"
# Define the (runtime) user
USER jboss
# Define the (runtime) working directory
WORKDIR /home/jboss
# Define the default run cmd
CMD ["/opt/eap/bin/openshift-launch.sh"]
