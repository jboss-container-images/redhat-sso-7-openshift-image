package org.jboss.test.arquillian.ce.sso;

import io.fabric8.kubernetes.api.model.v3_1.Pod;
import io.fabric8.kubernetes.clnt.v3_1.dsl.ExecListener;
import io.fabric8.openshift.api.model.v3_1.DeploymentConfigStatus;
import io.fabric8.openshift.api.model.v3_1.DoneableDeploymentConfig;
import okhttp3.Response;
import org.arquillian.cube.openshift.api.OpenShiftResource;
import org.arquillian.cube.openshift.api.Template;
import org.arquillian.cube.openshift.api.TemplateParameter;
import org.arquillian.cube.openshift.impl.client.OpenShiftAssistant;
import org.arquillian.cube.openshift.impl.client.ResourceUtil;
import org.arquillian.cube.openshift.impl.enricher.RouteURL;
import org.arquillian.cube.openshift.impl.utils.Containers;
import org.hamcrest.Matcher;
import org.jboss.arquillian.container.test.api.RunAsClient;
import org.jboss.arquillian.junit.Arquillian;
import org.jboss.arquillian.test.api.ArquillianResource;
import org.jboss.test.arquillian.ce.sso.support.WaitUtils;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URL;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static java.util.concurrent.TimeUnit.SECONDS;
import static org.hamcrest.CoreMatchers.allOf;
import static org.hamcrest.CoreMatchers.containsString;
import static org.hamcrest.Matchers.not;

/**
 * @author mhajas
 */
@RunWith(Arquillian.class)
@Template(url = "file://${user.dir}/../../templates/sso74-https.json",
        labels = "application=sso",
        parameters = {
                @TemplateParameter(name = "IMAGE_STREAM_NAMESPACE", value = "${kubernetes.namespace:openshift}"),
                @TemplateParameter(name = "SSO_ADMIN_USERNAME", value = "admin"),
                @TemplateParameter(name = "SSO_ADMIN_PASSWORD", value = "admin"),
                @TemplateParameter(name = "HTTPS_NAME", value = "jboss"),
                @TemplateParameter(name = "HTTPS_PASSWORD", value = "mykeystorepass"),
                @TemplateParameter(name = "SSO_VAULT_DIR", value = "/etc/sso-vault-secret-volume")

        })
@OpenShiftResource("https://raw.githubusercontent.com/${template.repository:jboss-openshift}/application-templates/${template.branch:master}/secrets/sso-app-secret.json")
@OpenShiftResource("{\n" +
        "  \"apiVersion\": \"v1\",\n" +
        "  \"data\": {\n" +
        "    \"master_smtp__password\": \"bXlTTVRQUHNzd2Q=\"\n" +
        "  },\n" +
        "  \"kind\": \"Secret\",\n" +
        "  \"metadata\": {\n" +
        "    \"name\": \"keycloak-vault-secrets\"\n" +
        "  },\n" +
        "  \"type\": \"Opaque\"\n" +
        "}")
public class Sso74VaultTest extends SsoTestBase {

    @RouteURL("sso")
    private URL routeURL;

    @RouteURL("secure-sso")
    private URL secureRouteURL;

    @ArquillianResource
    OpenShiftAssistant assistant;

    private static final String SSO_VAULT_DIR = "/etc/sso-vault-secret-volume";
    private static final String DEPLOYMENT_CONFIG_NAME = "sso";
    private static final Integer EXEC_TIMEOUT = 60;

    @Override
    protected URL getRouteURL() {
        return routeURL;
    }

    @Override
    protected URL getSecureRouteURL() {
        return secureRouteURL;
    }

    private static class SimpleListener implements ExecListener {
        public void onOpen(Response response) {
            System.out.println("Exec open");
        }

        public void onFailure(Throwable e, Response response) {
            System.err.println("Exec failure");
            e.printStackTrace();
        }

        public void onClose(int code, String reason) {
            System.out.println("Exec close");
        }
    }

    @Test
    @RunAsClient
    public void testVaultConfigured() throws Exception {
        try {
            Map<String, String> labels = Collections.singletonMap("application", DEPLOYMENT_CONFIG_NAME);

            exec(labels, EXEC_TIMEOUT,
                    allOf(containsString("\"outcome\" => \"success\""),
                            not(containsString("\"vault\" => undefined"))),
                    "bash", "-c", "$JBOSS_HOME/bin/jboss-cli.sh --connect --command=/subsystem=keycloak-server:read-resource");

            editDeploymentConfig()
                        .editSpec()
                            .editTemplate()
                                .editSpec()
                                    .addNewVolume()
                                    .withName("keycloak-vault-secret-volume")
                                    .withNewSecret()
                                        .withSecretName("keycloak-vault-secrets")
                                        .endSecret()
                                    .endVolume()
                                    .editFirstContainer()
                                        .addNewVolumeMount()
                                            .withName("keycloak-vault-secret-volume")
                                            .withMountPath(SSO_VAULT_DIR)
                                            .withReadOnly(true)
                                        .endVolumeMount()
                                        .addNewEnv()
                                            .withName("SSO_VAULT_DIR")
                                            .withValue(SSO_VAULT_DIR)
                                        .endEnv()
                                    .endContainer()
                                .endSpec()
                            .endTemplate()
                        .endSpec()
                    .done();

            waitForRHSSOToStart();

            exec(labels, EXEC_TIMEOUT,
                    allOf(containsString("\"outcome\" => \"success\""),
                            containsString("\"vault\" => undefined")),
                    "bash", "-c", "$JBOSS_HOME/bin/jboss-cli.sh --connect --command=/subsystem=keycloak-server:read-resource");
        } catch (Exception e) {
            e.printStackTrace();
            throw e;
        }
    }

    private DoneableDeploymentConfig editDeploymentConfig() {
        return assistant.getClient()
                .deploymentConfigs()
                .withName(DEPLOYMENT_CONFIG_NAME)
                .edit();
    }

    private void waitForReplicas(long startupTimeout, long checkPeriod, int expectedNumberOfReplicas) throws Exception {
        Containers.delay(startupTimeout, checkPeriod, () -> {
            DeploymentConfigStatus status = assistant.getClient().deploymentConfigs().withName(DEPLOYMENT_CONFIG_NAME).get().getStatus();
            Integer updatedReplicas = Optional.ofNullable(status.getUpdatedReplicas()).orElse(0);
            Integer availableReplicas = Optional.ofNullable(status.getAvailableReplicas()).orElse(0);
            Integer readyReplicas = Optional.ofNullable(status.getReadyReplicas()).orElse(0);

            return updatedReplicas == expectedNumberOfReplicas &&
                    availableReplicas == expectedNumberOfReplicas &&
                    readyReplicas == expectedNumberOfReplicas;
        });
    }

    private void waitForRHSSOToStart() throws Exception {
        // First wait for DeploymentConfig to be updated and pod to be spawned
        waitForReplicas(120, 3000, 1);

        // Then wait for RHSSO route to return status 200
        ResourceUtil.awaitRoute(getRouteURL(), 200);
    }

    private void exec(Map<String, String> labels, long waitLimitInSeconds, Matcher<String> matcher, String... input) throws Exception {
        List<Pod> pods = assistant.getClient().pods().withLabels(labels).list().getItems();
        if (pods.isEmpty()) {
            throw new IllegalStateException("No such pod: " + labels);
        }
        Pod targetPod = pods.get(0);

        ByteArrayOutputStream output = new ByteArrayOutputStream();
        assistant.getClient().pods().withName(targetPod.getMetadata().getName())
                .readingInput(System.in)
                .writingOutput(output)
                .writingError(System.err)
                .withTTY()
                .usingListener(new SimpleListener())
                .exec(input);

        WaitUtils.waitForCondition(() -> {
            try {
                output.flush();
            } catch (IOException e) {
                e.printStackTrace();
            }
            return output.toString();
        }, matcher, waitLimitInSeconds, SECONDS);
    }
}
