#!/bin/bash

# This script builds the image locally

# pnc list-built-artifacts -q 'filename=like="%.zip"' BUILD_ID | ./get-artifacts.py > artifacts-override.yaml

#JDK=openjdk
JDK=openj9

BUILDER=osbs
#BUILDER=podman

cekit --redhat --verbose \
  --descriptor image.yaml \
  build \
        --overrides-file "overrides/$JDK.yaml" \
        --overrides-file artifacts-override.yaml \
  $BUILDER
