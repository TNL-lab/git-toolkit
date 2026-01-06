#!/usr/bin/env bash
set -euo pipefail

############################################
# INIT
############################################
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [[ -n "${TOOLKIT_ROOT:-}" ]]; then
  TOOLKIT_DIR="$(cd "$TOOLKIT_ROOT" && pwd)"
else
  TOOLKIT_DIR="$REPO_ROOT"
fi

CONFIG_FILE=".git-toolkit.yml"

if [[ -n "${TOOLKIT_SCRIPTS:-}" ]]; then
  SCRIPT_DIR="$(cd "$TOOLKIT_SCRIPTS" && pwd)"
else
  SCRIPT_DIR="$TOOLKIT_DIR/scripts"
fi

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/runner.sh"
source "$SCRIPT_DIR/lib/packages.sh"

############################################
# CONFIG
############################################
DRY_RUN="$(yq -r '.release.dryRun // "false"' "$CONFIG_FILE" || echo "false")"
DRY_RUN="${DRY_RUN,,}" # normalize to lowercase

log "Dry-run mode: $DRY_RUN"

############################################
# LOAD COMMITS SINCE LAST TAG
############################################
log "Fetching tags..."
set +e
git fetch --tags 2>&1
FE=$?
set -e
if [[ $FE -ne 0 ]]; then
  log "⚠️ git fetch --tags failed (exit $FE), continuing anyway"
fi

LAST_TAG="$(git tag --sort=-creatordate | head -n 1)"

if [[ -z "$LAST_TAG" ]]; then
  log "No tag found → scanning all commits"
  mapfile -t COMMITS_ARRAY < <(git log --pretty=format:%s 2>/dev/null || true)
else
  log "Last tag: $LAST_TAG"
  mapfile -t COMMITS_ARRAY < <(git log "${LAST_TAG}..HEAD" --pretty=format:%s 2>/dev/null || true)
fi

if [[ "${#COMMITS_ARRAY[@]}" -eq 0 ]]; then
  log "No new commits since last tag → skipping version bump"
  exit 0
fi

############################################
# PACKAGE-AWARE VERSIONING
############################################
declare -A PACKAGE_BUMPS=()

for commit_msg in "${COMMITS_ARRAY[@]}"; do
  bump_type="$(get_bump_type "$commit_msg" "$CONFIG_FILE")"
  [[ -z "$bump_type" ]] && continue

  package_name="$(get_package_from_commit "$commit_msg" "$CONFIG_FILE")"
  [[ -z "$package_name" ]] && continue

  current_bump="${PACKAGE_BUMPS[$package_name]:-}"

  if should_override_bump "$current_bump" "$bump_type"; then
    PACKAGE_BUMPS["$package_name"]="$bump_type"
  fi
done <<< "$COMMITS"

if [[ "${#PACKAGE_BUMPS[@]}" -eq 0 ]]; then
  log "No package requires version bump"
  exit 0
fi

############################################
# APPLY PER PACKAGE
############################################
for package_name in "${!PACKAGE_BUMPS[@]}"; do
  bump_type="${PACKAGE_BUMPS[$package_name]}"

  if ! is_valid_package "$package_name" "$CONFIG_FILE"; then
    log "⚠️ Skipping invalid package: $package_name"
    continue
  fi

  version_file="$(get_package_version_file "$package_name" "$CONFIG_FILE")"

  if [[ -z "$version_file" ]]; then
    log "⚠️ No versionFile configured for package '$package_name'"
    continue
  fi

  if [[ ! -f "$version_file" ]]; then
    log "⚠️ VERSION file not found: $version_file"
    continue
  fi

  current_version="$(cat "$version_file")"
  new_version="$(bump_semver "$current_version" "$bump_type")"

  log "📦 $package_name: $current_version → $new_version ($bump_type)"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "💧 DRY-RUN: $package_name would bump to $new_version"
    continue
  fi

  echo "$new_version" > "$version_file"

  run_cmd git add "$version_file"
  run_cmd git commit -m "chore(release): bump ${package_name} to ${new_version}"
  run_cmd git tag "${package_name}-v${new_version}"
done

############################################
# PUSH
############################################
if [[ "$DRY_RUN" != "true" ]]; then
  run_cmd git push origin HEAD --tags
fi

log "✅ Multi-package version bump completed"
