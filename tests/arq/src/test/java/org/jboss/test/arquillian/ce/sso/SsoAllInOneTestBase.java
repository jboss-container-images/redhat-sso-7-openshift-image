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

import org.apache.http.cookie.Cookie;
import org.arquillian.cube.openshift.impl.enricher.RouteURL;
import org.jboss.arquillian.container.test.api.RunAsClient;
import org.jboss.test.arquillian.ce.sso.support.Client;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.junit.Test;

import java.net.URL;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import static org.junit.Assert.*;

public abstract class SsoAllInOneTestBase extends SsoEapTestBase {
			
    public SsoAllInOneTestBase() {
    }

    @RouteURL("helloworld")
    private URL routeURL;

    @RouteURL("secure-helloworld")
    private URL secureRouteURL;

    @RouteURL("secure-sso")
    private URL secureSsoRouteURL;

    @Override
    protected URL getRouteURL() {
        return routeURL;
    }

    @Override
    protected URL getSecureRouteURL() {
        return secureRouteURL;
    }
    
    protected String getRoute() {
        return getRouteURL().toString().replace(":80", "");
    }
	
    protected String getSecureRoute() {
        return getSecureRouteURL().toString().replace(":443", "");
    }

    @Test
    @RunAsClient
    public void testLogin() throws Exception {
        testLogin(getRoute());
    }

    @Test
    @RunAsClient
    public void testSecureLogin() throws Exception {
        testLogin(getSecureRoute());
    }

    protected void testLogin(String host) throws Exception {
        Client client = new Client(host);

        String result = client.get("app-profile-jsp/profile.jsp");
        assertContains(result, "kc-form-login");
    }

    @Test
    @RunAsClient
    public void testOidcLogin() throws Exception {
        Client client = login(getRoute(), "app-profile-jsp/profile.jsp");
        
        String result = client.get();
        assertContains(result, "First name", "Last name", "Username", "demouser");
    }

    @Test
    @RunAsClient
    public void testSecureOidcLogin() throws Exception {
    	Client client = login(getSecureRoute(), "app-profile-jsp/profile.jsp");
    	
    	String result = client.get();
        assertContains(result, "First name", "Last name", "Username", "demouser");
    }

    protected Client login(String host, String key) throws Exception {
    	Client client = new Client(host);
        String result = client.get(key);
        assertContains(result, "kc-form-login");
        
        int index = result.indexOf("action");
        String action=result.substring(index + "action=\"".length());
        index = action.indexOf("\"");
        action=action.substring(0,index);
         
        client.setBasicUrl(action);
        
        Map<String, String> params = new HashMap<>();
        params.put("username", "demouser");
        params.put("password", "demopass");
        params.put("login", "submit");
        client.setParams(params);
        
        result = client.post();
        
        assertContains(result, Client.trimPort(host));
        
        client.setBasicUrl(result);
        params = new HashMap<>();
        client.setParams(params);
        
        return client;
    }

    @Test
    @RunAsClient
    public void testAccessType() throws Exception {
        Client client = new Client(secureSsoRouteURL.toString());
        String accessToken = client.getToken("admin", "admin");

        Map<String, String> params = new HashMap<>();
        params.put("Accept", "application/json");
        params.put("Authorization", "Bearer " + accessToken);

        String result = client.get("/auth/admin/realms/demo/clients", params);

        JSONParser jsonParser = new JSONParser();
        Iterator clients = ((JSONArray) jsonParser.parse(result)).iterator();
        while (clients.hasNext()) {
        	JSONObject jsonObject = (JSONObject) clients.next();
            if ((jsonObject.get("clientId")).equals("app-jsp")) {
                assertEquals(jsonObject.get("publicClient"), Boolean.FALSE);
                assertEquals(jsonObject.get("bearerOnly"), Boolean.FALSE);
                return;
            }
        }

        fail("ClientId app-jsp not found");
    }
    
    @Test
    @RunAsClient
    public void testSecureAppJspButtonsNoLogin() throws Exception {
    	Client client = new Client(getSecureRoute());
        String result = client.get("app-jsp/index.jsp");
        assertContains(result, "Public", "Secured", "Admin");
         
        Map<String, String> params = new HashMap<>();
        params.put("action", "public");
        client.setParams(params);
        
        result = client.post("app-jsp/index.jsp");
        assertContains(result, "Message: public");
        
        params.put("action", "secured");
        client.setParams(params);
        
        result = client.post("app-jsp/index.jsp");
        assertTrue(String.format("Result does not contain the expected value. Content: %s", result),
                result.contains("Internal Server Error") && result.contains("500")
                        || result.contains("HTTP Status 500"));
    }
    
    @Test
    @RunAsClient
    public void testSecureAppJspButtonsLogin() throws Exception {
    	Client client = login(getSecureRoute(), "app-jsp/protected.jsp");
       
        String result = client.get();
        assertContains(result, "Public", "Secured", "Admin", "Logout", "Account");

        Map<String, String> params = new HashMap<>();
        params.put("action", "public");
        client.setParams(params);
        client.setBasicUrl(getSecureRoute());

        result = client.post("app-jsp/index.jsp");
        assertContains(result, "Message: public");
        
        params.put("action", "secured");
        client.setParams(params);
        
        result = client.post("app-jsp/index.jsp");
        assertContains(result, "Message: secured");

        printCookieStore(client);
    }
    
    private void printCookieStore(Client client) throws Exception {
    	List<Cookie> cookies = client.getCookieStore().getCookies();
    	System.out.println("Cookies " + cookies.size());
    	for (Cookie cookie : cookies){
    		System.out.println("      " + cookie);
    	}
    }
}