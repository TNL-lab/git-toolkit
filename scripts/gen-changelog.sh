#!/usr/bin/env bash
set -euo pipefail

#Resolve root repo directory
ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR"

# Config
CONFIG=".git-toolkit.yml"
OUTPUT="CHANGELOG.md"
TEMPLATE="templates/CHANGELOG.template.md"
# Validations
command -v yq >/dev/null 2>&1 || {
  echo "❌ yq is required but not installed"
  exit 1
}

[[ -f "$CONFIG_FILE" ]] || {
  echo "❌ Missing $CONFIG_FILE"
  exit 1
}

[[ -f "$TEMPLATE_FILE" ]] || {
  echo "❌ Missing $TEMPLATE_FILE"
  exit 1
}

# Read configuration values from framework repository
TAG_PREFIX=$(yq '.toolkit.phase.tag_prefix' "$CONFIG")
[[ -n "$TAG_PREFIX" ]] || {
  echo "❌ tag_prefix is empty in .git-toolkit.yml"
  exit 1
}

# Get list of tags phase and sort them by version
TAGS=$(git tag --list "${TAG_PREFIX}-*" --sort=version:refname)
if [[ -z "$TAGS" ]]; then
  echo "⚠️ No tags found with prefix ${TAG_PREFIX}"
  exit 0
fi

# Init CHANGELOG
cp "$TEMPLATE" "$OUTPUT"
echo "" >> "$OUTPUT"

# Generate changelog entries for each tag
PREV_TAG=""

for TAG in $TAGS; do
  TITLE=$(git tag -l "$TAG" -n99 | sed "s/^$TAG\s*//")

    echo "## $TITLE" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

  if [[ -n "$PREV_TAG" ]]; then
    RANGE="$PREV_TAG..$TAG"
  else
    RANGE="$TAG"
  fi


  git log "$RANGE" \
    --pretty=format:"- %s" \
    --no-merges >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  PREV_TAG="$TAG"

done

echo "✅ CHANGELOG.md generated successfully"
