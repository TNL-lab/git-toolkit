#!/usr/bin/env bash
set -euo pipefail

CONFIG=".git-toolkit.yml"
OUTPUT="CHANGELOG.md"
TEMPLATE="tools/git/git-toolkit/templates/CHANGELOG.template.md"

# Read configuration values from framework repository
TAG_PREFIX=$(yq '.toolkit.phase.tag_prefix' "$CONFIG")

# Get list of tags phase and sort them by version
TAGS=$(git tag --list "${TAG_PREFIX}-*" --sort=version:refname)

#Reset CHANGELOG file from template
cp "$TEMPLATE" "$OUTPUT"
echo "" >> "$OUTPUT"

# Generate changelog entries for each tag
PREV_TAG=""

for TAG in $TAGS; do
  TITLE=$(git tag -l "$TAG" -n99 | sed "s/^$TAG\s*//")

  echo "## $TITLE" >> "$OUTPUT"

  if [[ -n "$PREV_TAG" ]]; then
    RANGE="$PREV_TAG..$TAG"
  else
    RANGE="$TAG"
  fi

  git log "$RANGE" --pretty=format:"- %s" >> "$OUTPUT"
  echo "" >> "$OUTPUT"

  PREV_TAG="$TAG"
done
