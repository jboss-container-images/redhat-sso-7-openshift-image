#!/usr/bin/env bash

set -eu

# Install the 'dejavu-sans-fonts' IBM Semeru 11 JDK RPM dependency first
# Moreover, install also 'jq' later to parse the release info JSON file of
# latest IBM Semeru 11 JDK GitHub tag (release)
microdnf -y install dejavu-sans-fonts jq && microdnf clean all

# Given the architecture
# shellcheck disable=SC2155
readonly ARCH=$(uname -i)

# Get the release info JSON file for latest IBM Semeru 11 JDK tag from GitHub
# shellcheck disable=SC2155
readonly LATEST_SEMERU_11_JDK_RELEASE_JSON=$(
  curl --header "Accept: application/vnd.github.v3+json" --show-error --silent \
  "https://api.github.com/repos/ibmruntimes/semeru11-binaries/releases/latest"
)

# Out of all assets published for latest IBM Semeru 11 JDK release select just
# the download URL of RPM package specific for this architecture
# shellcheck disable=SC2155
readonly LATEST_SEMERU_11_JDK_RPM=$(
  # Return URL of that asset from release info, having 'content_type' set to
  # 'application/x-rpm', ending with '${ARCH}.rpm}' and not being a JRE RPM
  jq '.assets[]
      | select(.content_type == "application/x-rpm")
      | .browser_download_url
      | select(endswith("'"${ARCH}"'.rpm") and (contains("jre") | not))' \
  <<< "${LATEST_SEMERU_11_JDK_RELEASE_JSON[@]}" | tr -d '"'
)

# Import the IBM Semeru Runtimes public GPG key
# URL below from https://www.ibm.com/support/pages/semeru-runtimes-verification/
# section "RPM Package Manager packages (.rpm)"
rpm --import "https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/certificates/ibm-semeru-public-GPGkey.pgp"

# Download the latest IBM Semeru 11 JDK Open Edition RPM
curl -OLJ --show-error --silent "${LATEST_SEMERU_11_JDK_RPM}"

# Verify the signatures & digests of the downloaded RPM are correct
rpmkeys -Kv "./$(basename "${LATEST_SEMERU_11_JDK_RPM}")"

# If so, install the RPM
rpm -i "./$(basename "${LATEST_SEMERU_11_JDK_RPM}")"

# Make latest IBM Semeru 11 JDK the default JDK
alternatives --set java /usr/lib/jvm/ibm-semeru-open-11-jdk/bin/java
alternatives --set javac /usr/lib/jvm/ibm-semeru-open-11-jdk/bin/javac
export JAVA_SECURITY_FILE=/usr/lib/jvm/ibm-semeru-open-11-jdk/conf/security/java.security
export JAVA_HOME=/usr/lib/jvm/ibm-semeru-open-11-jdk

# Remove the (formerly default) OpenJDK 11 RPM packages
rpm --erase --nodeps java-11-openjdk{,-devel,-headless}
