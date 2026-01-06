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
# INTERNAL STATE
############################################
CREATED_TAGS=()

############################################
# FETCH LAST TAG
############################################
log "Fetching tags..."
set +e
git fetch --tags 2>&1
FE=$?
set -e
if [[ $FE -ne 0 ]]; then
  log "⚠️ git fetch --tags failed (exit $FE), continuing anyway"
fi

############################################
# PACKAGE-AWARE VERSIONING
############################################
declare -A PACKAGE_BUMPS=()

for package in $(list_packages "$CONFIG_FILE"); do
  last_tag="$(get_last_package_tag "$package")"

  if [[ -z "$last_tag" ]]; then
    log "📦 $package: no previous tag → scanning all commits"
    mapfile -t commits < <(git log --pretty=format:%s 2>/dev/null || true)
  else
    log "📦 $package: last tag = $last_tag"
    mapfile -t commits < <(git log "${last_tag}..HEAD" --pretty=format:%s 2>/dev/null || true)
  fi

  for commit_msg in "${commits[@]}"; do
    commit_package="$(get_package_from_commit "$commit_msg" "$CONFIG_FILE" 2>/dev/null || echo "")"
    [[ "$commit_package" != "$package" ]] && continue

    bump_type="$(get_bump_type "$commit_msg" "$CONFIG_FILE" 2>/dev/null || echo "")"
    [[ -z "$bump_type" ]] && continue

    current="${PACKAGE_BUMPS[$package]:-}"
    if should_override_bump "$current" "$bump_type"; then
      PACKAGE_BUMPS["$package"]="$bump_type"
    fi
  done
done

if [[ "${#PACKAGE_BUMPS[@]}" -eq 0 ]]; then
  log "No package requires version bump"
  exit 0
fi

############################################
# APPLY PER PACKAGE
############################################
for package in "${!PACKAGE_BUMPS[@]}"; do
  bump="${PACKAGE_BUMPS[$package]}"

  if ! is_valid_package "$package" "$CONFIG_FILE"; then
    log "⚠️ Invalid package: $package"
    continue
  fi

  version_file="$(get_package_version_file "$package" "$CONFIG_FILE" 2>/dev/null || echo "")"
  if [[ -z "$version_file" ]]; then
    log "⚠️ $package has no versionFile configured"
    continue
  fi

  if [[ ! -f "$version_file" ]]; then
    log "ℹ️ Creating VERSION file for $package"
    mkdir -p "$(dirname "$version_file")"
    echo "0.0.0" > "$version_file"
  fi


  current_version="$(cat "$version_file" 2>/dev/null || echo "")"
  new_version="$(bump_semver "$current_version" "$bump")"
  TAG_NAME="${package}-v${new_version}"

  log "📦 $package: $current_version → $new_version ($bump)"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "💧 DRY-RUN: skip write/tag for $package"
    continue
  fi

  echo "$new_version" > "$version_file"

  run_cmd git add "$version_file"
  run_cmd git commit -m "chore(release): bump ${package} to ${new_version}" || log "⚠️ Nothing to commit for $package"

  if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    log "⚠️ Tag $TAG_NAME already exists, skipping tag creation"
  else
    run_cmd git tag "$TAG_NAME"
    CREATED_TAGS+=("$TAG_NAME")
  fi
done

############################################
# PUSH
############################################
if [[ "$DRY_RUN" != "true" ]]; then
  run_cmd git push origin HEAD

  for tag in "${CREATED_TAGS[@]}"; do
    run_cmd git push origin "$tag"
  done
fi

log "✅ Multi-package version bump completed"
