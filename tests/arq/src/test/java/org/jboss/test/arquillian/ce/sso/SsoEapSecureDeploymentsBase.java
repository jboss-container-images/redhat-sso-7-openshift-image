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
import org.jboss.arquillian.container.test.api.RunAsClient;
import org.jboss.arquillian.test.api.ArquillianResource;
import org.junit.Test;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.Collections;
import java.util.Map;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public abstract class SsoEapSecureDeploymentsBase extends SsoTestBase {
    @ArquillianResource
    OpenShiftHandle adapter;

    @Override
    protected URL getHealthCheckUrl() {
        try {
            return new URL(super.getHealthCheckUrl() + "app-profile-jee");
        } catch (MalformedURLException e) {
            throw new RuntimeException(e);
        }
    }

    @Test
    @RunAsClient
    public void testLogs() throws Exception {
        Map<String, String> labels = Collections.singletonMap("application", "eap-app");
        String result = adapter.getLog(null, labels);

        assertFalse(result.contains("Failure"));
        assertTrue(result.contains("Deployed \"app-profile-jee.war\""));
        assertTrue(result.contains("Deployed \"app-profile-jee-saml.war\""));
    }

}
