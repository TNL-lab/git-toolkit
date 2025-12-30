#!/usr/bin/env bash
set -euo pipefail

# Root repo
ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR"

# Config
CONFIG=".git-toolkit.yml"
TEMPLATE="${TOOLKIT_ROOT}/templates/CHANGELOG.template.md"
OUTPUT="CHANGELOG.md"

# Validations
command -v yq >/dev/null 2>&1 || {
  echo "❌ yq is required but not installed"
  exit 1
}

[[ -f "$CONFIG" ]] || {
  echo "❌ Missing $CONFIG"
  exit 1
}

[[ -f "$TEMPLATE" ]] || {
  echo "❌ Missing $TEMPLATE"
  exit 1
}

# Read config
TAG_PREFIX=$(yq '.toolkit.phase.tag_prefix' "$CONFIG")
[[ -n "$TAG_PREFIX" ]] || {
  echo "❌ tag_prefix is empty in $CONFIG"
  exit 1
}

# List tags
TAGS=$(git tag --list "${TAG_PREFIX}-*" --sort=version:refname)
if [[ -z "$TAGS" ]]; then
  echo "⚠️ No tags found with prefix ${TAG_PREFIX}"
  exit 0
fi

# Init CHANGELOG
cp "$TEMPLATE" "$OUTPUT"
echo "" >> "$OUTPUT"

PREV_TAG=""
for TAG in $TAGS; do
  TITLE=$(git tag -l "$TAG" -n99 | sed "s/^$TAG\s*//")

  echo "## $TITLE" >> "$OUTPUT"
  echo "" >> "$OUTPUT"

  if [[ -n "$PREV_TAG" ]]; then
    RANGE="$PREV_TAG..$TAG"
  else
    RANGE="$TAG"
  fi

  git log "$RANGE" \
    --pretty=format:"- %s" \
    --no-merges >> "$OUTPUT"
  echo "" >> "$OUTPUT"

  PREV_TAG="$TAG"
done

echo "✅ CHANGELOG.md generated at $OUTPUT"
