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

import org.arquillian.cube.openshift.api.OpenShiftDynamicImageStreamResource;
import org.arquillian.cube.openshift.api.OpenShiftResource;
import org.jboss.arquillian.ce.httpclient.*;
import org.jboss.arquillian.container.test.api.RunAsClient;
import org.junit.Test;

@OpenShiftResource("https://raw.githubusercontent.com/${template.repository:jboss-openshift}/application-templates/${template.branch:master}/secrets/eap7-app-secret.json")
@OpenShiftResource("https://raw.githubusercontent.com/${template.repository:jboss-openshift}/application-templates/${template.branch:master}/secrets/eap-app-secret.json")
@OpenShiftDynamicImageStreamResource(name = "${imageStream.eap71.name:jboss-eap71-openshift}", image = "${imageStream.eap71.image:registry.access.redhat.com/jboss-eap-7/eap71-openshift:1.3}", version = "${imageStream.eap71.version:1.3}")
@OpenShiftDynamicImageStreamResource(name = "${imageStream.eap64.name:jboss-eap64-openshift}", image = "${imageStream.eap64.image:registry.access.redhat.com/jboss-eap-6/eap64-openshift:1.8}", version = "${imageStream.eap64.version:1.8}")
public abstract class SsoEapTestBase extends SsoTestBase {

    private final HttpClientExecuteOptions execOptions = new HttpClientExecuteOptions.Builder().tries(3)
            .desiredStatusCode(200).delay(10).build();

    protected String getRoute() {
        return getRouteURL().toString().replace(":80", "");
    }

    protected String getSecureRoute() {
        return getSecureRouteURL().toString().replace(":443", "");
    }

    @Test
    @RunAsClient
    public void testAppProfileJeeRoute() throws Exception {
        appRoute(getRoute(), "app-profile-jsp", "profile.jsp", "Please login");
    }

    @Test
    @RunAsClient
    public void testSecureAppProfileJeeRoute() throws Exception {
        appRoute(getSecureRoute(), "app-profile-jsp", "profile.jsp", "Please login");
    }

    @Test
    @RunAsClient
    public void testAppProfileJeeSamlRoute() throws Exception {
        appRoute(getRoute(), "app-profile-saml", "profile.jsp", "Please login");
    }

    @Test
    @RunAsClient
    public void testSecureAppProfileJeeSamlRoute() throws Exception {
        appRoute(getSecureRoute(), "app-profile-saml", "profile.jsp", "Please login");
    }

    protected void appRoute(String host, String app, String... expecteds) throws Exception {
        HttpClient client = HttpClientBuilder.untrustedConnectionClient();
        HttpRequest request = HttpClientBuilder.doGET(host + app);
        HttpResponse response = client.execute(request, execOptions);

        String result = response.getResponseBodyAsString();
        assertContains(result, expecteds);
    }
}
