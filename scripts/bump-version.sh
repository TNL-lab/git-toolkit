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
source "$SCRIPT_DIR/lib/packages.sh"

CONFIG_FILE=".git-toolkit.yml"

############################################
# CONFIG
############################################
DRY_RUN="$(yq '.release.dryRun // false' "$CONFIG_FILE")"

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
# PACKAGE-AWARE VERSIONING
############################################
source "$SCRIPT_DIR/lib/packages.sh"

declare -A PACKAGE_BUMPS

while read -r commit; do
  bump="$(get_bump_type "$commit")"
  [[ -z "$bump" ]] && continue

  pkg="$(get_package_from_commit "$commit")"
  [[ -z "$pkg" ]] && continue

  current="${PACKAGE_BUMPS[$pkg]:-}"

  if should_override_bump "$current" "$bump"; then
    PACKAGE_BUMPS["$pkg"]="$bump"
  fi
done <<< "$COMMITS"

if [[ "${#PACKAGE_BUMPS[@]}" -eq 0 ]]; then
  log "No package requires version bump"
  exit 0
fi

############################################
# APPLY PER PACKAGE
############################################
  log "📦 $pkg: $current_version → $new_version ($bump)"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "💧 DRY-RUN: $pkg would bump to $new_version"
    continue
  fi

  echo "$new_version" > "$version_file"

  run_cmd git add "$version_file"
  run_cmd git commit -m "chore(release): bump $pkg to $new_version"
  run_cmd git tag "$pkg-v$new_version"
done

############################################
# PUSH
############################################
if [[ "$DRY_RUN" != "true" ]]; then
  run_cmd git push origin HEAD --tags
fi

log "✅ Multi-package version bump completed"