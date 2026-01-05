#!/usr/bin/env bash
set -euo pipefail

############################################
# INIT
############################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

CONFIG_FILE=".git-toolkit.yml"

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/runner.sh"

TAG="${1:-}"

if [[ -z "$TAG" ]]; then
  echo "❌ Usage: $0 <tag>"
  exit 1
fi

[[ -f "$CONFIG_FILE" ]] || {
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
}

############################################
# LOAD ALLOWED COMMIT TYPES
############################################
mapfile -t ALLOWED_TYPES < <(yq -r '.commit.types.allowed[]' "$CONFIG_FILE")
if [[ "${#ALLOWED_TYPES[@]}" -eq 0 ]]; then
  echo "❌ No allowed commit types defined in $CONFIG_FILE"
  exit 1
fi

############################################
# LOAD SEMANTIC GROUP TITLES
############################################
declare -A RELEASE_TITLES
declare -A RELEASE_COMMITS

for type in "${ALLOWED_TYPES[@]}"; do
  RELEASE_TITLES[$type]=$(get_semantic_group_title "$type")
  RELEASE_COMMITS[$type]=""
done

############################################
# TAG TITLES
############################################
TITLE=$(git tag -l "$TAG" -n99 | sed "s/^${TAG}[[:space:]]*//")
TITLE="${TITLE:-Release $TAG}"

PREV_TAG=$(git describe --tags --abbrev=0 "${TAG}^" 2>/dev/null || echo "")

############################################
# COLLECT COMMITS
############################################
if [[ -n "$PREV_TAG" ]]; then
  COMMITS=$(git log "$PREV_TAG..$TAG" --pretty=format:"%s" --no-merges)
else
  COMMITS=$(git log "$TAG" --pretty=format:"%s" --no-merges)
fi

while read -r line; do
  for type in "${ALLOWED_TYPES[@]}"; do
    if [[ "$line" =~ ^$type\(.+\) ]]; then
      RELEASE_COMMITS[$type]+="- $line"$'\n'
      break
    fi
  done
done <<< "$COMMITS"

############################################
# RENDER RELEASE NOTES
############################################
echo "# $TITLE"
echo ""
echo "## Changes"
echo ""

for type in "${ALLOWED_TYPES[@]}"; do
  content="${RELEASE_COMMITS[$type]:-}"
  if [[ -n "$content" ]]; then
    echo "### ${RELEASE_TITLES[$type]}"
    echo ""
    echo -e "$content"
  fi
done

log "✅ RELEASE.md generated"
