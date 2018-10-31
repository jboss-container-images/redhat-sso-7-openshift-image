/*
 * JBoss, Home of Professional Open Source
 * Copyright 2015 Red Hat Inc. and/or its affiliates and other
 * contributors as indicated by the @author tags. All rights reserved.
 * See the copyright.txt in the distribution for a full listing of
 * individual contributors.
 *
 * This is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA, or see the FSF site: http://www.fsf.org.
 */

package org.jboss.test.arquillian.ce.sso;

import org.arquillian.cube.openshift.api.OpenShiftHandle;
import org.arquillian.cube.openshift.api.OpenShiftResource;
import org.arquillian.cube.openshift.api.Template;
import org.arquillian.cube.openshift.api.TemplateParameter;
import org.arquillian.cube.openshift.impl.enricher.RouteURL;
import org.jboss.arquillian.container.test.api.RunAsClient;
import org.jboss.arquillian.junit.Arquillian;
import org.jboss.arquillian.test.api.ArquillianResource;
import org.junit.Ignore;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.net.URL;
import java.util.Collections;
import java.util.Map;

import static org.junit.Assert.assertTrue;

@RunWith(Arquillian.class)
@Template(url = "https://raw.githubusercontent.com/${template.repository:jboss-openshift}/application-templates/${template.branch:master}/eap/eap64-sso-s2i.json",
        labels = "application=eap-app",
        parameters = {
                @TemplateParameter(name = "IMAGE_STREAM_NAMESPACE", value = "${kubernetes.namespace:openshift}"),
                @TemplateParameter(name = "HTTPS_NAME", value = "jboss"),
                @TemplateParameter(name = "HTTPS_PASSWORD", value = "mykeystorepass"),
                @TemplateParameter(name = "SSO_URL", value = "http://ssoeap64envtest.${kubernetes.domain:cloudapps.example.com}/auth"),
                @TemplateParameter(name = "HOSTNAME_HTTP", value = "ssoeap64envtest.${kubernetes.domain:cloudapps.example.com}"),
                @TemplateParameter(name = "HOSTNAME_HTTPS", value = "secure-ssoeap64envtest.${kubernetes.domain:cloudapps.example.com}"),
                @TemplateParameter(name = "SSO_REALM", value = "demo"),
                @TemplateParameter(name = "SSO_SAML_LOGOUT_PAGE", value = "profile.jsp"),
                @TemplateParameter(name = "SSO_ENABLE_CORS", value = "true"),
                @TemplateParameter(name = "SSO_PUBLIC_KEY", value = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiLezsNQtZSaJvNZXTmjhlpIJnnwgGL5R1vkPLdt7odMgDzLHQ1h4DlfJPuPI4aI8uo8VkSGYQXWaOGUh3YJXtdO1vcym1SuP8ep6YnDy9vbUibA/o8RW6Wnj3Y4tqShIfuWf3MEsiH+KizoIJm6Av7DTGZSGFQnZWxBEZ2WUyFt297aLWuVM0k9vHMWSraXQo78XuU3pxrYzkI+A4QpeShg8xE7mNrs8g3uTmc53KR45+wW1icclzdix/JcT6YaSgLEVrIR9WkkYfEGj3vSrOzYA46pQe6WQoenLKtIDFmFDPjhcPoi989px9f+1HCIYP0txBS/hnJZaPdn5/lEUKQIDAQAB")
        })
@Ignore("Message: Forbidden! User arq-sso/HOST doesn't have permission. pods is forbidden: User \"arq-sso\" cannot list pods at the cluster scope: User \"arq-sso\" cannot list all pods in the cluster.")
public class SsoEap64EnvTest extends SsoEapTestBase {
    @RouteURL("eap-app")
    private URL routeURL;

    @RouteURL("secure-eap-app")
    private URL secureRouteURL;

    @ArquillianResource
    OpenShiftHandle adapter;

    @Override
    protected URL getRouteURL() {
        return routeURL;
    }

    @Override
    protected URL getSecureRouteURL() {
        return secureRouteURL;
    }

    @Test
    @RunAsClient
    public void testConfiguration() throws Exception {
        Map<String, String> labels = Collections.singletonMap("application", "eap-app");
        String result = adapter.exec(labels, 30, "cat", "/opt/eap/standalone/configuration/standalone-openshift.xml");

        assertTrue(result.contains("<enable-cors>true</enable-cors>"));
        assertTrue(result.contains("logoutPage=\"profile.jsp\""));
    }

}
