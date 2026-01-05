#!/usr/bin/env bash
set -euo pipefail

TAG="$1"

if [[ -z "$TAG" ]]; then
  echo "❌ Usage: gen-release-notes.sh <tag>"
  exit 1
fi

# Load config
ALLOWED_TYPES=$(yq '.commit.allowed_types | join("|")' .git-toolkit.yml)
declare -A GROUPS
for type in $ALLOWED_TYPES; do
  GROUPS[$type]=""
done

# Get tag title
TITLE=$(git tag -l "$TAG" -n99 | sed "s/^$TAG\s*//")

# Get previous tag
PREV_TAG=$(git describe --tags --abbrev=0 "$TAG"^ 2>/dev/null || echo "")

# Collect commits
if [[ -n "$PREV_TAG" ]]; then
  COMMITS=$(git log "$PREV_TAG..$TAG" --pretty=format:"%s")
else
  COMMITS=$(git log "$TAG" --pretty=format:"%s")
fi

# Group commits
while read -r line; do
  for type in $ALLOWED_TYPES; do
    if [[ "$line" =~ ^$type\(.+\) ]]; then
      GROUPS[$type]+="- $line\n"
      break
    fi
  done
done <<< "$COMMITS"

# Print semantic release notes
echo "# $TITLE"
echo ""
echo "## Changes"
for type in $ALLOWED_TYPES; do
  content=${GROUPS[$type]}
  if [[ -n "$content" ]]; then
    title=$(yq ".release.semantic_groups.$type" .git-toolkit.yml)
    echo "### $title"
    echo -e "$content"
  fi
done
