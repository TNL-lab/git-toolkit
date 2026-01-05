#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/runner.sh"

TAG="${1:-}"

if [[ -z "$TAG" ]]; then
  echo "❌ Usage: bump-version.sh <tag>"
  exit 1
fi

CONFIG_FILE=".git-toolkit.yml"

VERSION_FILE="${VERSION_FILE:-$(yq '.version.file' "$CONFIG_FILE")}"

if [[ -z "$VERSION_FILE" || "$VERSION_FILE" == "null" ]]; then
  echo "❌ version.file not defined in $CONFIG_FILE"
  exit 1
fi

# Expect: toolkit-v1.2.3
if [[ ! "$TAG" =~ v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "❌ Invalid tag format. Expected <prefix>-vMAJOR.MINOR.PATCH"
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
VERSION="$MAJOR.$MINOR.$PATCH"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "💧 DRY-RUN mode: VERSION would be bumped to $VERSION"
  exit 0
fi

echo "$VERSION" > "$VERSION_FILE"
echo "🔖 VERSION updated to $VERSION in $VERSION_FILE"

run_cmd git add "$VERSION_FILE"
run_cmd git commit -m "chore(release): bump version to $VERSION"
run_cmd git push origin HEAD

echo "✅ VERSION bump committed & pushed"
