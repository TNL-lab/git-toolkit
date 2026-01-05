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
  local commit_msg="$1"
  local scope

  scope="$(extract_scope "$commit_msg")"

  # No scope → ignore
  [[ -z "$scope" ]] && return

  # Only allow real packages
  if is_valid_package "$scope"; then
    echo "$scope"
  fi
}

is_valid_package() {
  local package="$1"

  # packages defined in .git-toolkit.yml
  yq -e ".packages.$package" .git-toolkit.yml >/dev/null 2>&1
}
