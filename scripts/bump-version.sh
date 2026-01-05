#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"

if [[ -z "$TAG" ]]; then
  echo "❌ Usage: bump-version.sh <tag>"
  exit 1
fi

CONFIG_FILE=".git-toolkit.yml"

VERSION_FILE=$(yq '.version.file' "$CONFIG_FILE")

if [[ -z "$VERSION_FILE" || "$VERSION_FILE" == "null" ]]; then
  echo "❌ version.file not defined"
  exit 1
fi

# Expect: toolkit-v1.2.3
if [[ ! "$TAG" =~ v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "❌ Invalid tag format. Expected <prefix>-vMAJOR.MINOR.PATCH"
  exit 1
fi

VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"

echo "🔖 Bumping version to $VERSION"

echo "$VERSION" > "$VERSION_FILE"

echo "✅ VERSION updated"
