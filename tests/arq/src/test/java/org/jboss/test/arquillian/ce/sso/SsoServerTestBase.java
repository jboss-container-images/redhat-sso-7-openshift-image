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

import org.jboss.arquillian.ce.httpclient.*;
import org.jboss.arquillian.container.test.api.RunAsClient;
import org.junit.Test;

import java.util.HashMap;
import java.util.Map;

import static org.hamcrest.CoreMatchers.anyOf;
import static org.hamcrest.CoreMatchers.containsString;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertThat;
import static org.junit.Assert.assertTrue;

public abstract class SsoServerTestBase extends SsoTestBase {

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
    public void testConsoleRoute() throws Exception {
        consoleRoute(getRoute());
    }

    @Test
    @RunAsClient
    public void testSecureConsoleRoute() throws Exception {
        consoleRoute(getSecureRoute());
    }

    protected void consoleRoute(String host) throws Exception {
        HttpClient client = HttpClientBuilder.untrustedConnectionClient();
        String url = host + "auth/admin/master/console";
        url = url.replace(":443", "");
        url = url.replace(":80", "");
        HttpRequest request = HttpClientBuilder.doGET(url);
        HttpResponse response = client.execute(request, execOptions);
        String result = response.getResponseBodyAsString();
        assertThat(result, anyOf(containsString("Log in to rh-sso"), containsString("data-ng-show=\"auth.user\""), containsString("id=\"kc-login\"")));
    }

    @Test
    @RunAsClient
    public void testRestRoute() throws Exception {
        restRoute(getRoute());
    }

    @Test
    @RunAsClient
    public void testSecureRestRoute() throws Exception {
        restRoute(getSecureRoute());
    }

    protected void restRoute(String host) throws Exception {


        HttpClient client = HttpClientBuilder.untrustedConnectionClient();
        HttpRequest request = HttpClientBuilder.doPOST(host + "auth/realms/master/protocol/openid-connect/token");

        Map<String, String> params = new HashMap<String, String>();
        params.put("username", "admin");
        params.put("password", "admin");
        params.put("grant_type", "password");
        params.put("client_id", "admin-cli");
        request.setEntity(params);

        HttpResponse response = client.execute(request, execOptions);

        String result = response.getResponseBodyAsString();

        assertFalse(result.contains("error_description"));
        assertTrue(result.contains("access_token"));
    }

    @Test
    @RunAsClient
    public void testLogin() throws Exception {
        login(getRoute());
    }

    @Test
    @RunAsClient
    public void testSecureOidcLogin() throws Exception {
        login(getSecureRoute());
    }

    protected void login(String host) throws Exception {
        HttpClient client = HttpClientBuilder.untrustedConnectionClient();
        HttpRequest request = HttpClientBuilder.doPOST(host + "auth");

        Map<String, String> params = new HashMap<String, String>();
        params.put("username", "admin");
        params.put("password", "admin");
        params.put("login", "submit");
        request.setEntity(params);

        HttpResponse response = client.execute(request, execOptions);
        assertTrue(response.getResponseBodyAsString().contains("Welcome to Red Hat Single Sign-On"));
    }
}
