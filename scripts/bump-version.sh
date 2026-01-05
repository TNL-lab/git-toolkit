#!/usr/bin/env bash
set -euo pipefail

############################################
# INIT
############################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/runner.sh"

CONFIG_FILE=".git-toolkit.yml"

############################################
# CONFIG
############################################
VERSION_FILE="$(yq '.version.file' "$CONFIG_FILE")"
DRY_RUN="$(yq '.release.dryRun // false' "$CONFIG_FILE")"

if [[ -z "$VERSION_FILE" || "$VERSION_FILE" == "null" ]]; then
  echo "❌ version.file not defined in $CONFIG_FILE"
  exit 1
fi

CURRENT_VERSION="$(cat "$VERSION_FILE")"

log "Current version: $CURRENT_VERSION"
log "Dry-run mode: $DRY_RUN"

############################################
# LOAD COMMITS SINCE LAST TAG
############################################
git fetch --tags

LAST_TAG="$(git tag --sort=-creatordate | head -n 1)"

if [[ -z "$LAST_TAG" ]]; then
  log "No tag found → scanning all commits"
  COMMITS=$(git log --pretty=format:%s)
else
  log "Last tag: $LAST_TAG"
  COMMITS=$(git log "$LAST_TAG"..HEAD --pretty=format:%s)
fi

############################################
# DETECT BUMP TYPE (LEVEL 20)
############################################
FINAL_BUMP=""

while read -r commit; do
  bump="$(get_bump_type "$commit")"
  [[ -z "$bump" ]] && continue

  if should_override_bump "$FINAL_BUMP" "$bump"; then
    FINAL_BUMP="$bump"
  fi
done <<< "$COMMITS"

if [[ -z "$FINAL_BUMP" ]]; then
  log "No version bump required"
  exit 0
fi

log "Detected bump type: $FINAL_BUMP"

############################################
# CALCULATE NEW VERSION
############################################
NEW_VERSION="$(bump_semver "$CURRENT_VERSION" "$FINAL_BUMP")"

log "New version: $NEW_VERSION"

############################################
# DRY RUN
############################################
if [[ "$DRY_RUN" == "true" ]]; then
  echo "💧 DRY-RUN: version would be bumped from $CURRENT_VERSION → $NEW_VERSION"
  exit 0
fi

############################################
# APPLY VERSION
############################################
echo "$NEW_VERSION" > "$VERSION_FILE"

run_cmd git add "$VERSION_FILE"
run_cmd git commit -m "chore(release): bump version to $NEW_VERSION"
run_cmd git tag "v$NEW_VERSION"
run_cmd git push origin HEAD --tags

log "✅ VERSION bump completed"
