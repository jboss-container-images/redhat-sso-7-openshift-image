#!/bin/sh
set -u
set -e

## Work around https://bugzilla.redhat.com/show_bug.cgi?id=1797054
if rpm -q java-1.8.0-openjdk-headless && ( rpm -q java-11-openjdk-devel || rpm -q java-11-openj9-devel ); then
    for pkg in java-1.8.0-openjdk-devel \
           java-1.8.0-openjdk-headless \
           java-1.8.0-openjdk; do
        if rpm -q "$pkg"; then
            rpm -e --nodeps "$pkg"
        fi
    done
fi

## Work around OpenJDK being installed as dependency. https://bugzilla.redhat.com/show_bug.cgi?id=1762827 and similar
if rpm -q java-11-openj9-devel; then
    for pkg in java-11-openjdk-devel \
           java-11-openjdk-headless \
           java-11-openjdk; do
        if rpm -q "$pkg"; then
            rpm -e --nodeps "$pkg"
        fi
    done
fi

