## Using Red Hat Single Sign-On 7.5 container images with alternative JDK

The Red Hat Single Sign-On 7.5 for OpenJDK container images use the [Red Hat OpenJDK 11](https://access.redhat.com/documentation/en-us/openjdk/11/html-single/getting_started_with_openjdk_11/index#openjdk-overview), a free and open source implementation of the Java Platform, Standard Edition (Java SE) by default.

To provide an illustrative example on how to install an alternative JDK and instruct the Red Hat Single Sign-On 7.5 container images to use it, the 'ibm-semeru-open-11-jdk' subdirectory contains a definition of Red Hat Single Sign-On 7.5 container file switching the JDK runtime to the latest available release of [IBM Semeru Runtime Open Edition Java 11 (LTS)](https://github.com/ibmruntimes/semeru11-binaries/releases/latest).

## Building the Red Hat Single Sign-On 7.5 container image with latest release of IBM Semeru 11 JDK Open Edition

You can build this example by creating a new build using OpenShift CLI (oc) tool. Specify:
* The vanilla `rh-sso-7/sso75-openshift-rhel8` image stream to use as the builder,
* The Docker build strategy to use for build execution, and
* The Git repository, branch name and particular context directory within the repository as the source of the build

.Prerequisites

* Ensure you have [OpenShift CLI (oc) installed](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html#installing-openshift-cli)
* Make sure you have [Registry Service Account](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.5/html-single/red_hat_single_sign-on_for_openshift/index#image-streams-applications-templates) to access the secured Red Hat Registry *registry.redhat.io*. Be sure you can use the secret for pulling images for pods, and also for pushing and pulling build images. See the [Red Hat Container Registry Authentication](https://access.redhat.com/RegistryAuthentication) article for more information. 
* Moreover, assure you have [the Red Hat Single Sign-On 7.5.X OpenShift image stream installed](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.5/html-single/red_hat_single_sign-on_for_openshift/index#image-streams-applications-templates) in the *openshift* project.

.Procedure

1. Ensure that you are logged in as a cluster administrator or a user with project administrator access to the global `openshift` project. Choose the following command based on your version of OpenShift Container Platform:

   * If you are running an OpenShift Container Platform v3 based cluster instance on (some) of your master host(s), perform the following:

      ```
      $ oc login -u system:admin
      ```

   * If you are running an OpenShift Container Platform v4 based cluster instance, [log in to the CLI](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html#cli-logging-in_cli-developer-commands) as the [kubeadmin](https://docs.openshift.com/container-platform/latest/authentication/remove-kubeadmin.html#understanding-kubeadmin_removing-kubeadmin) user:

      ```
      $ oc login -u kubeadmin -p password https://openshift.example.com:6443
      ```

2. Execute the following command:

   ```
   $ oc new-build \
     --context-dir=jdk/ibm-semeru-open-11-jdk \
     --image-stream=openshift/sso75-openshift-rhel8:7.5 \
     --name=sso75-openshift-rhel8-ibm-semeru-11-jdk \
     --namespace=openshift \
     --strategy=docker \
     https://github.com/jboss-container-images/redhat-sso-7-openshift-image.git#sso75-dev
   ```

When submitted, this command creates a new `sso75-openshift-rhel8-ibm-semeru-11-jdk` BuildConfig definition in the global `openshift` project and launches a build from it. Moreover, a new `sso75-openshift-rhel8-ibm-semeru-11-jdk` ImageStream is also created in the global `openshift` project.

## Acquiring OpenShift templates for the new Red Hat Single Sign-On 7.5 container `sso75-openshift-rhel8-ibm-semeru-11-jdk` image stream

You can obtain OpenShift templates for the newly produced `sso75-openshift-rhel8-ibm-semeru-11-jdk` image stream by performing the following modifications [to the standard templates available for the Red Hat Single Sign-On 7.5 container image](https://github.com/jboss-container-images/redhat-sso-7-openshift-image/tree/sso75-dev/templates):

   * Change the default image stream name and image tag from `"sso75-openshift-rhel8:7.5"` to `"sso75-openshift-rhel8-ibm-semeru-11-jdk"`,

   * Optinally add a custom suffix to the name of the original template later better to distinguish the newly created templates for IBM Semeru 11 JDK Open Edition from the original one. Alternatively, if **you just want to modify** [**the default Red Hat Single Sign-On 7.5 container image OpenShift templates**](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.5/html-single/red_hat_single_sign-on_for_openshift#sso-templates) to start using the new `sso75-openshift-rhel8-ibm-semeru-11-jdk` image stream, then **define the custom suffix to be empty string**.

### Modifying the default Red Hat Single Sign-On 7.5 container image templates to use `"sso75-openshift-rhel8-ibm-semeru-11-jdk"` image stream

Use this option if you want to continue using the [**the default Red Hat Single Sign-On 7.5 container image OpenShift templates**](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.5/html-single/red_hat_single_sign-on_for_openshift#sso-templates) with the new `sso75-openshift-rhel8-ibm-semeru-11-jdk` image stream.

.Prerequisites

* Ensure you have [the default OpenShift templates for Red Hat Single Sign-On 7.5 container image installed](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.5/html-single/red_hat_single_sign-on_for_openshift/index#image-streams-applications-templates).

.Procedure

1. Set TEMPLATE\_SUFFIX environment variable to empty string and run the `acquire-ibm-semeru-open-11-jdk-rh-sso-templates.sh` helper script as follows:

   ```
   $ TEMPLATE_SUFFIX="" ./ibm-semeru-open-11-jdk/scripts/templates/acquire-ibm-semeru-open-11-jdk-rh-sso-templates.sh
   ```

   In this case the `./ibm-semeru-open-11-jdk/scripts/templates/acquire-ibm-semeru-open-11-jdk-rh-sso-templates.sh` script will just change the image stream name from `"sso75-openshift-rhel8:7.5"` to `"sso75-openshift-rhel8-ibm-semeru-11-jdk"` for each of the default Red Hat Single Sign-On 7.5 container image templates.

   As a result, the output of the script looks as follows:

      ```
      $ TEMPLATE_SUFFIX="" ./ibm-semeru-open-11-jdk/scripts/templates/acquire-ibm-semeru-open-11-jdk-rh-sso-templates.sh
      template.template.openshift.io "sso75-https" deleted
      template.template.openshift.io/sso75-https replaced
      template.template.openshift.io "sso75-postgresql" deleted
      template.template.openshift.io/sso75-postgresql replaced
      template.template.openshift.io "sso75-postgresql-persistent" deleted
      template.template.openshift.io/sso75-postgresql-persistent replaced
      template.template.openshift.io "sso75-x509-https" deleted
      template.template.openshift.io/sso75-x509-https replaced
      template.template.openshift.io "sso75-x509-postgresql" deleted
      template.template.openshift.io/sso75-x509-postgresql-persistent replaced
      ```

### Generating IBM Semeru 11 JDK Open Edition specific Red Hat Single Sign-On 7.5 container image templates

Use this option if you want a new template with custom suffix in its name to be created for each of the default RH-SSO templates using the `sso75-openshift-rhel8-ibm-semeru-11-jdk` image stream.

.Prerequisites

* Ensure you have [the default OpenShift templates for Red Hat Single Sign-On 7.5 container image installed](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.5/html-single/red_hat_single_sign-on_for_openshift/index#image-streams-applications-templates).


.Procedure

1. Set TEMPLATE\_SUFFIX environment variable to contain the desired suffix for newly generated templates, for example `"-ibm-semeru-11-jdk"`. Then run the `acquire-ibm-semeru-open-11-jdk-rh-sso-templates.sh` helper script as follows:


   ```
   $ TEMPLATE_SUFFIX="-ibm-semeru-11-jdk" ./ibm-semeru-open-11-jdk/scripts/templates/acquire-ibm-semeru-open-11-jdk-rh-sso-templates.sh
   ```

   In this case the `./ibm-semeru-open-11-jdk/scripts/templates/acquire-ibm-semeru-open-11-jdk-rh-sso-templates.sh` script:

   1. First creates a Semeru JDK 11 counterpart copy of the particular default template with specified template suffix appended to the file name of the original template,
   2. Updates the `.metadata.name` field of that template copy to match the new name of the template,
   3. Replaces the name of the default image stream in the `sso` DeploymentConfig definition of the template with `sso75-openshift-rhel8-ibm-semeru-11-jdk` image stream,
   4. Finally, recreates the template with the new name using the updated image stream in the global `openshift` project.

   As a result, the output of the script looks as follows:

      ```
      $ TEMPLATE_SUFFIX="-ibm-semeru-11-jdk" ./ibm-semeru-open-11-jdk/scripts/templates/acquire-ibm-semeru-open-11-jdk-rh-sso-templates.sh
      template.template.openshift.io "sso75-https-ibm-semeru-11-jdk" deleted
      template.template.openshift.io/sso75-https-ibm-semeru-11-jdk replaced
      template.template.openshift.io "sso75-postgresql-ibm-semeru-11-jdk" deleted
      template.template.openshift.io/sso75-postgresql-ibm-semeru-11-jdk replaced
      template.template.openshift.io "sso75-postgresql-persistent-ibm-semeru-11-jdk" deleted
      template.template.openshift.io/sso75-postgresql-persistent-ibm-semeru-11-jdk replaced
      template.template.openshift.io "sso75-x509-https-ibm-semeru-11-jdk" deleted
      template.template.openshift.io/sso75-x509-https-ibm-semeru-11-jdk replaced
      template.template.openshift.io "sso75-x509-postgresql-persistent-ibm-semeru-11-jdk" deleted
      template.template.openshift.io/sso75-x509-postgresql-persistent-ibm-semeru-11-jdk replaced
      ```

## Deploying Red Hat Single Sign-On 7.5 container image with latest release of IBM Semeru 11 JDK Open Edition

You can deploy Red Hat Single Sign-On 7.5 container image using latest IBM Semeru 11 JDK Open Edition as usual. The only differing step is the name of the template to use depending if default templates were overwritten, or new ones were generated.

.Procedure

1. Create a `semeru-demo` project:

   ```
   $ oc new-project semeru-demo
   ```

2. Create a new application, using the Red Hat Single Sign-On 7.5 container image with latest release of IBM Semeru 11 JDK Open Edition as usual. For example, run:

   ```
   $ oc new-app --template=sso75-x509-https
   ```

   if you previously modified the default `sso75-x509-https` template to start using the `sso75-openshift-rhel8-ibm-semeru-11-jdk`, or run

   ```
   $ oc new-app --template=sso75-x509-https-ibm-semeru-11-jdk
   ```

   if you previously generated IBM Semeru 11 JDK Open Edition templates using the `-ibm-semeru-11-jdk` suffix and want to deploy the IBM Semeru counterpart of `sso75-x509-https` template.

## References

* [IBM Semeru Runtimes Open Edition for Java 11 binaries GitHub repository](https://github.com/ibmruntimes/semeru11-binaries)
* [IBM Semeru Runtimes main GitHub repository](https://github.com/ibmruntimes/Semeru-Runtimes)
* [IBM Semeru Runtimes website](https://developer.ibm.com/languages/java/semeru-runtimes)
* [IBM Semeru Runtimes support page](https://www.ibm.com/support/pages/semeru-runtimes-support/)
