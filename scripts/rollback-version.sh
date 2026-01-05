#!/usr/bin/env bash
set -euo pipefail

############################################
# INIT
############################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

CONFIG_FILE=".git-toolkit.yml"

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/runner.sh"

############################################
# ARGUMENTS
############################################
TARGET_VERSION="${1:-}"

if [[ -z "$TARGET_VERSION" ]]; then
  echo "❌ Usage: $0 <version>"
  exit 1
fi

############################################
# LOAD VERSION FILE FROM CONFIG
############################################
VERSION_FILE="$(yq -r '.version.rootFile // empty' "$CONFIG_FILE")"

if [[ -z "$VERSION_FILE" ]]; then
  echo "❌ version.rootFile not defined in $CONFIG_FILE"
  exit 1
fi

############################################
# DRY-RUN CHECK
############################################
if [[ "${DRY_RUN:-false}" == "true" ]]; then
  log "💧 DRY-RUN: VERSION would be rolled back to $TARGET_VERSION"
  exit 0
fi

############################################
# APPLY ROLLBACK
############################################
echo "$TARGET_VERSION" > "$VERSION_FILE"

log "↩️ Rolling back to version $TARGET_VERSION"

run_cmd git add "$VERSION_FILE"
run_cmd git commit -m "chore(release): rollback version to $TARGET_VERSION"
run_cmd git push origin HEAD

log "✅ Rollback committed & pushed"
