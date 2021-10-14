#!/bin/sh
set -u
set -e

## Work around OpenJDK being installed as dependency. https://bugzilla.redhat.com/show_bug.cgi?id=1762827 and similar
if rpm -q ibm-semeru-open-11-jdk || rpm -q java-11-openj9-devel; then
    for pkg in java-11-openjdk-devel \
           java-11-openjdk-headless \
           java-11-openjdk; do
        if rpm -q "$pkg"; then
            rpm -e --nodeps "$pkg"
        fi
    done
fi

