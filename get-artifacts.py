#!/usr/bin/python

# Usage: pnc list-built-artifacts -q 'filename=like="%.zip"' BUILD_ID | ./get-artifacts.py > artifacts-override.yaml

import json
import re
import sys

FILE_RES = (
    ("keycloak-server-overlay.zip",     re.compile(r"keycloak-server-overlay-.*\.zip", re.I)),
    ("keycloak-eap6-adapter.zip",       re.compile(r"keycloak-eap6-adapter-dist-.*\.zip", re.I)),
    ("keycloak-eap7-adapter.zip",       re.compile(r"keycloak-wildfly-adapter-dist-.*\.zip", re.I)),
    ("keycloak-fuse-adapter.zip",       re.compile(r"keycloak-fuse-adapter-dist-.*\.zip", re.I)),
    ("keycloak-js-adapter.zip",         re.compile(r"keycloak-js-adapter-dist-.*\.zip", re.I)),
    ("keycloak-saml-eap6-adapter.zip",  re.compile(r"keycloak-saml-eap6-adapter-dist-.*\.zip", re.I)),
    ("keycloak-saml-eap7-adapter.zip",  re.compile(r"keycloak-saml-wildfly-adapter-dist-.*\.zip", re.I)),
)

build_artifacts = json.load(sys.stdin)

print("schema_version: 1\nartifacts:")

def is_matching_artifact(a):
    for f in FILE_RES:
        if (f[1].match(a['filename'])):
            return f
    return None

for a in build_artifacts:
    b = is_matching_artifact(a)
    if b:
        print("- target: %s\n  name: %s\n  md5: %s\n  url: %s" % (b[0], b[0], a['md5'], a['public_url']))
