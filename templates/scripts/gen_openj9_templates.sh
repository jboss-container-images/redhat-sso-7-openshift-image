#!/usr/bin/env bash

SRC_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
DEST_DIR="${SRC_DIR}/openj9"

for original_template in "$SRC_DIR"/*.json; do
  echo "Creating OpenJ9 template for file $(basename "$original_template")"
  NEW_TEMPLATE_NAME="${DEST_DIR}/$(basename "$original_template" | sed -e 's/\([a-zA-Z0-9]*\)-/\1-openj9-/')"

  sed -e 's/OpenJDK/OpenJ9/' \
    -e 's/sso\([0-9]\{2,\}\)/sso\1-openj9/' \
    "$original_template" \
    >"$NEW_TEMPLATE_NAME"
done
