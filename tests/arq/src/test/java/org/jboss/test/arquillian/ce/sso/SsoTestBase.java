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
import org.arquillian.cube.openshift.impl.client.ResourceUtil;
import org.arquillian.cube.openshift.impl.utils.Checker;
import org.arquillian.cube.openshift.impl.utils.Containers;
import org.junit.Before;

import static org.junit.Assert.assertTrue;

import java.net.URL;
import java.util.logging.Logger;


/**
 * @author Filippe Spolti
 * @author Ales justin
 */
@OpenShiftDynamicImageStreamResource(
  name = "${imageStream.sso.name:sso75-openshift-rhel8}",
  image = "${imageStream.sso.image:registry.access.redhat.com/sso-7/sso75-openshift-rhel8:7.5}",
  version = "${imageStream.sso.version:7.5}"
)
public abstract class SsoTestBase {
    protected final Logger log = Logger.getLogger(getClass().getName());
    protected static final String DEPLOYMENT_CONFIG_NAME = "sso";

    protected abstract URL getRouteURL();

    protected abstract URL getSecureRouteURL();

    protected URL getHealthCheckUrl() {
        return getRouteURL();
    }

    @Before
    public void initialStateAwait() throws Exception {
        Containers.delay(300, 3000, initialStateChecker());
    }

    protected Checker initialStateChecker() {
        return () -> {
                log.info("Waiting for route: " + getHealthCheckUrl() + " to return 200");
                ResourceUtil.awaitRoute(getHealthCheckUrl(), 200);
                return true;
            };
    }

    public static void assertContains(String content, String... expecteds) {
        for (String expected : expecteds)
            assertTrue(String.format("String does not contain the expected value \"%s\". Content: %s", expected, content), content.contains(expected));
    }
}
