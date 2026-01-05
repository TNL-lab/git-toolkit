#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/runner.sh"

TARGET_VERSION="${1:-}"

if [[ -z "$TARGET_VERSION" ]]; then
  echo "❌ Usage: rollback-version.sh <version>"
  exit 1
fi

VERSION_FILE="${VERSION_FILE:-$(yq '.version.file' "$CONFIG_FILE")}"

if [[ -z "$VERSION_FILE" || "$VERSION_FILE" == "null" ]]; then
  echo "❌ version.file not defined in $CONFIG_FILE"
  exit 1
fi

if [[ "${DRY_RUN:-false}" == "true" ]]; then
  echo "💧 DRY-RUN mode: VERSION would be rolled back to $TARGET_VERSION"
  exit 0
fi

echo "$TARGET_VERSION" > "$VERSION_FILE"

echo "↩️ Rolling back to version $TARGET_VERSION"



run_cmd git add "$VERSION_FILE"
run_cmd git commit -m "chore(release): rollback version to $TARGET_VERSION"
run_cmd git push origin HEAD

echo "✅ Rollback committed & pushed"