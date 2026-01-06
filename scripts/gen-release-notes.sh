#!/usr/bin/env bash
set -euo pipefail

############################################
# INIT
############################################
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [[ -n "${TOOLKIT_ROOT:-}" ]]; then
  TOOLKIT_DIR="$(cd "$TOOLKIT_ROOT" && pwd)"
else
  TOOLKIT_DIR="$REPO_ROOT"
fi

CONFIG_FILE=".git-toolkit.yml"

if [[ -n "${TOOLKIT_SCRIPTS:-}" ]]; then
  SCRIPT_DIR="$(cd "$TOOLKIT_SCRIPTS" && pwd)"
else
  SCRIPT_DIR="$TOOLKIT_DIR/scripts"
fi

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
  RELEASE_TITLES[$type]=$(get_semantic_group_title "$type" "$CONFIG_FILE")
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
  mapfile -t COMMITS_ARRAY < <(git log "$PREV_TAG..$TAG" --pretty=format:"%s" --no-merges 2>/dev/null || true)
else
  mapfile -t COMMITS_ARRAY < <(git log "$TAG" --pretty=format:"%s" --no-merges 2>/dev/null || true)
fi

############################################
# CLASSIFY COMMITS
############################################
for line in "${COMMITS_ARRAY[@]}"; do
  for type in "${ALLOWED_TYPES[@]}"; do
    if [[ "$line" =~ ^$type\(.+\) ]]; then
      RELEASE_COMMITS[$type]+="- $line"$'\n'
      break
    fi
  done
done

############################################
# RENDER RELEASE NOTES
############################################
{
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
} > RELEASE.md

log "✅ RELEASE.md generated"
