#!/usr/bin/env bash
set -euo pipefail

############################################
# DRY RUN
############################################
run_cmd() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    echo "🟡 DRY-RUN: $*"
  else
    echo "▶ RUN: $*"
    "$@"
  fi
}

############################################
# GET SEMANTIC GROUP
############################################
get_semantic_group_title() {
  local type="$1"
  local config_file="$2"
  yq -r ".release.semantic_groups.$type" "$config_file"
}


############################################
# LOGGING
############################################
log() {
  echo "▶ $1"
}

############################################
# SEMVER
############################################
bump_semver() {
  local version="$1"
  local bump="$2"

  IFS='.' read -r major minor patch <<< "$version"

  case "$bump" in
    major) ((major++)); minor=0; patch=0 ;;
    minor) ((minor++)); patch=0 ;;
    patch) ((patch++)) ;;
    *) echo "$version"; return ;;
  esac

  echo "${major}.${minor}.${patch}"
}

############################################
# COMMIT PARSING
############################################

extract_scope() {
  local commit="$1"
  echo "$commit" | sed -n 's/^[a-zA-Z]\+(\([^)]\+\)):.*/\1/p'
}

get_bump_type() {
  local commit="$1"

  if grep -q "BREAKING CHANGE" <<<"$commit"; then
    echo "major"
    return
  fi

  case "$commit" in
    feat\(*\)* ) echo "minor" ;;
    fix\(*\)*|docs\(*\)*|test\(*\)*|refactor\(*\)*|style\(*\)*|chore\(*\)* )
      echo "patch"
      ;;
    * ) echo "" ;;
  esac
}

############################################
# BUMP PRIORITY
############################################
should_override_bump() {
  local current="$1"
  local incoming="$2"

  case "$incoming" in
    major) return 0 ;;
    minor) [[ "$current" != "major" ]] && return 0 ;;
    patch) [[ -z "$current" ]] && return 0 ;;
  esac

  return 1
}

