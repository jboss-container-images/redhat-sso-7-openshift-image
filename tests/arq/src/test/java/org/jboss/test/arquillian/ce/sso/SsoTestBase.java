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

import static org.junit.Assert.assertTrue;

import java.net.URL;
import java.util.logging.Logger;


/**
 * @author Filippe Spolti
 * @author Ales justin
 */
@OpenShiftResource("${openshift.imageStreams}")
@OpenShiftDynamicImageStreamResource(name = "${imageStream.sso-cd.name:redhat-sso-cd-openshift}", image = "${imageStream.sso-cd.image:registry.access.redhat.com/redhat-sso-7-tech-preview/sso-cd-openshift:1.0}", version = "${imageStream.sso-cd.version:1.0}")
public abstract class SsoTestBase {
    protected final Logger log = Logger.getLogger(getClass().getName());

    protected abstract URL getRouteURL();

    protected abstract URL getSecureRouteURL();

    public static void assertContains(String content, String... expecteds) {
        for (String expected : expecteds)
            assertTrue(String.format("String does not contain the expected value \"%s\". Content: %s", expected, content), content.contains(expected));
    }
}
