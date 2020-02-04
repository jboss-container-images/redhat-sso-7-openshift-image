#!/bin/sh
set -u
set -e

if ! rpm -q java-1.8.0-openj9-devel; then
  exit
fi

for pkg in java-1.8.0-openjdk-devel \
       java-1.8.0-openjdk-headless \
       java-1.8.0-openjdk; do
    if rpm -q "$pkg"; then
        rpm -e --nodeps "$pkg"
    fi
done
