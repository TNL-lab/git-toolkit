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
# SEMANTIC GROUP (FROM CONFIG)
############################################
get_semantic_group_title() {
  local type="$1"
  local config_file="$2"
  yq -r ".release.semanticGroups.${type} // \"\"" "$config_file"
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

extract_type() {
  local commit="$1"
  echo "$commit" | sed -n 's/^\([a-zA-Z]\+\)(.*/\1/p'
}

############################################
# BUMP TYPE (CONFIG DRIVEN)
############################################
get_bump_type() {
  local commit="$1"
  local config_file="$2"
  local type
  local breaking_keyword
  local bump

  breaking_keyword="$(yq -r '.release.breakingChange.keyword' "$config_file")"

  if grep -q "$breaking_keyword" <<<"$commit"; then
    echo "major"
    return
  fi

  type="$(extract_type "$commit")"
  [[ -z "$type" ]] && return

  bump="$(yq -r ".release.versionBumpRules.${type} // \"\"" "$config_file")"

  [[ "$bump" != "none" ]] && echo "$bump"
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
