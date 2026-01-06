#!/usr/bin/env bash
set -euo pipefail

############################################
# PACKAGE CONFIG
############################################

get_package_version_file() {
  local package="$1"
  local config_file="$2"

  yq -r ".packages.${package}.versionFile // \"\"" "$config_file"
}

list_packages() {
  yq -r '.packages | keys[]' "$CONFIG_FILE"
}

is_valid_package() {
  local package="$1"
  local config_file="$2"

  yq -e ".packages.${package}" "$config_file" >/dev/null 2>&1
}

############################################
# DETECT PACKAGE FROM COMMIT
############################################

get_package_from_commit() {
  local commit="$1"
  local config_file="$2"
  local scope

  scope="$(extract_scope "$commit")"
  [[ -z "$scope" ]] && return 0

  if is_meta_scope "$scope" "$config_file"; then
    return 0
  fi

  if is_valid_package "$scope" "$config_file"; then
    echo "$scope"
  fi
}

is_meta_scope() {
  local scope="$1"
  local config_file="$2"

  yq -e ".commit.scopes.meta[] | select(. == \"${scope}\")" \
    "$config_file" >/dev/null 2>&1
}
