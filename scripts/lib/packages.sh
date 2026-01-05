#!/usr/bin/env bash
set -euo pipefail

############################################
# PACKAGE CONFIG
############################################
get_package_version_file() {
  local package="$1"
  yq -r ".packages.list.$package" "$CONFIG_FILE"
}

list_packages() {
  yq -r '.packages.list | keys[]' "$CONFIG_FILE"
}

############################################
# DETECT PACKAGE FROM COMMIT
############################################
get_package_from_commit() {
  local commit="$1"
  extract_scope "$commit"
}