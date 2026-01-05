#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/runner.sh"

TAG="${1:-}"

if [[ -z "$TAG" ]]; then
  echo "❌ Usage: gen-release-notes.sh <tag>"
  exit 1
fi

CONFIG_FILE=".git-toolkit.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ $CONFIG_FILE not found"
  exit 1
fi

ALLOWED_TYPES=("${COMMIT_ALLOWED_TYPES[@]}")

# Load allowed commit types (LIST, not regex)
mapfile -t ALLOWED_TYPES < <(yq '.commit.allowed_types[]' "$CONFIG_FILE")

# Load semantic group titles
declare -A RELEASE_TITLES

# Prepare commit buckets
declare -A RELEASE_COMMITS

for type in "${ALLOWED_TYPES[@]}"; do
  RELEASE_TITLES[$type]=$(get_semantic_group_title "$type" "$CONFIG_FILE")
  RELEASE_COMMITS[$type]=""
done

# Get tag title
TITLE=$(git tag -l "$TAG" -n99 | sed "s/^$TAG\s*//")
TITLE="${TITLE:-Release $TAG}"

# Get previous tag
PREV_TAG=$(git describe --tags --abbrev=0 "$TAG"^ 2>/dev/null || echo "")

# Collect commits
if [[ -n "$PREV_TAG" ]]; then
  COMMITS=$(git log "$PREV_TAG..$TAG" --pretty=format:"%s" --no-merges)
else
  COMMITS=$(git log "$TAG" --pretty=format:"%s" --no-merges)
fi

# Group commits by type
while read -r line; do
  for type in "${ALLOWED_TYPES[@]}"; do
    if [[ "$line" =~ ^$type\(.+\) ]]; then
      RELEASE_COMMITS[$type]+="- $line"$'\n'
      break
    fi
  done
done <<< "$COMMITS"

# Render release notes
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

echo "✅ RELEASE.md generated"
