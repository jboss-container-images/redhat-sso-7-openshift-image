#!/bin/sh
# Red Hat Single Sign-On module to install & configure Python 3 binary
set -e

# Unmask 'python' alternatives alias & point it to Python 3 binary
alternatives --remove python /usr/libexec/no-python && alternatives --set python /usr/bin/python3
