/*
 * JBoss, Home of Professional Open Source
 * Copyright 2013, Red Hat, Inc. and/or its affiliates, and individual
 * contributors by the @authors tag. See the copyright.txt in the
 * distribution for a full listing of individual contributors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.jboss.test.arquillian.ce.sso.support;

import org.apache.http.client.CookieStore;
import org.apache.http.impl.client.BasicCookieStore;
import org.jboss.arquillian.ce.httpclient.HttpClient;
import org.jboss.arquillian.ce.httpclient.HttpClientBuilder;
import org.jboss.arquillian.ce.httpclient.HttpRequest;
import org.jboss.arquillian.ce.httpclient.HttpResponse;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

import java.util.HashMap;
import java.util.Map;
import java.util.logging.Logger;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;


public class Client {

    protected final Logger log = Logger.getLogger(getClass().getName());

    protected Map<String, String> params;
    protected String basicUrl;
    protected HttpClient client;
    protected CookieStore cookieStore = new BasicCookieStore();

    public Client(String basicUrl) throws Exception {
        this.basicUrl = trimPort(basicUrl);
        client = HttpClientBuilder.create().untrustedConnectionClientBuilder().setCookieStore(cookieStore).build();
    }

    public static String trimPort(String url) {
        if (url.contains(":443"))
            url = url.replace(":443", "");
        else if (url.contains(":80"))
            url = url.replace(":80", "");

        return url;
    }

    public void setParams(Map<String, String> params) {
        this.params = params;
    }

    public void setBasicUrl(String basicUrl) {
        this.basicUrl = basicUrl;
    }

    public String get() {
        return get(null, null);
    }

    public String get(String key) {
        return get(key, null);
    }

    public CookieStore getCookieStore() {
        return cookieStore;
    }

    public String get(String key, Map<String, String> headers) {
        try {
            String url = basicUrl;
            if (key != null) {
                url = basicUrl + "/" + key;
                if (basicUrl.endsWith("/"))
                    url = basicUrl + key;
            }

            HttpRequest request = HttpClientBuilder.doGET(url);

            if (headers != null) {
                for (Map.Entry<String, String> header : headers.entrySet())
                    request.setHeader(header.getKey(), header.getValue());
            }

            HttpResponse response = client.execute(request);

            int statusCode = response.getResponseCode();
            log.warning("Response Code : " + statusCode);

            return response.getResponseBodyAsString();
        } catch (Exception e) {
            e.printStackTrace();
            throw new RuntimeException(e);
        }
    }

    public String post() {
        return post(null);
    }

    public String post(String key) {
        try {
            String url = basicUrl;
            if (key != null) {
                url = basicUrl + "/" + key;
                if (basicUrl.endsWith("/"))
                    url = basicUrl + key;
            }

            HttpRequest request = HttpClientBuilder.doPOST(url);

            if (params != null)
                request.setEntity(params);

            HttpResponse response = client.execute(request);

            int statusCode = response.getResponseCode();

            log.warning("Response Code : " + statusCode);

            if (statusCode == 302) {
                String location = response.getHeader("Location");
                if (location != null) {
                    return location;
                }
            }

            if (statusCode != 200)
                return statusCode + " " + response.getResponseBodyAsString();
            else
                return response.getResponseBodyAsString();
        } catch (Exception e) {
            e.printStackTrace();
            throw new RuntimeException(e);
        }
    }

    public String getToken(String username, String password) throws Exception {
        Map<String, String> params = new HashMap<>();
        params.put("username", username);
        params.put("password", password);
        params.put("grant_type", "password");
        params.put("client_id", "admin-cli");

        setParams(params);
        String result = post("auth/realms/master/protocol/openid-connect/token");

        assertFalse(result.contains("error_description"));
        assertTrue(result.contains("access_token"));

        JSONParser jsonParser = new JSONParser();
        JSONObject jsonObject = (JSONObject) jsonParser.parse(result);
        String accessToken = (String) jsonObject.get("access_token");

        setParams(null);

        return accessToken;
    }
}