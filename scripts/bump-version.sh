#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"

if [[ -z "$TAG" ]]; then
  echo "❌ Usage: bump-version.sh <tag>"
  exit 1
fi

CONFIG_FILE=".git-toolkit.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ $CONFIG_FILE not found"
  exit 1
fi

VERSION_FILE=$(yq '.version.file' "$CONFIG_FILE")

if [[ -z "$VERSION_FILE" || "$VERSION_FILE" == "null" ]]; then
  echo "❌ version.file not defined in $CONFIG_FILE"
  exit 1
fi

# Extract numeric version from tag (toolkit-10 → 10)
VERSION="${TAG##*-}"

if [[ ! "$VERSION" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid tag format. Expected <prefix>-<number>"
  exit 1
fi

echo "🔖 Bumping version to $VERSION"

echo "$VERSION" > "$VERSION_FILE"

echo "✅ VERSION updated: $(cat "$VERSION_FILE")"
