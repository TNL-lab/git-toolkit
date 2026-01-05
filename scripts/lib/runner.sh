#!/usr/bin/env bash
set -euo pipefail

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "🟡 DRY-RUN: $*"
  else
    echo "▶ RUN: $*"
    "$@"
  fi
}

get_semantic_group_title() {
  local type="$1"
  local config_file="$2"
  yq -r ".release.semantic_groups.$type" "$config_file"
}