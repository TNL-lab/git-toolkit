#!/usr/bin/env bash
set -euo pipefail

############################################
# INIT
############################################
REPO_ROOT="$(git rev-parse --show-toplevel)"

TEMPLATE="$REPO_ROOT/templates/CHANGELOG.template.md"
CONFIG_FILE=".git-toolkit.yml"
OUTPUT="CHANGELOG.md"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libs
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/runner.sh"

############################################
# VALIDATIONS
############################################
command -v yq >/dev/null 2>&1 || {
  echo "❌ yq is required but not installed"
  exit 1
}

[[ -f "$CONFIG_FILE" ]] || {
  echo "❌ Missing $CONFIG_FILE"
  exit 1
}

[[ -f "$TEMPLATE" ]] || {
  echo "❌ Missing $TEMPLATE"
  exit 1
}

cd "$REPO_ROOT"
############################################
# READ CONFIG
############################################
PHASE_ENABLED="$(yq -r '.toolkit.phase.enabled // false' "$CONFIG_FILE")"
TAG_PREFIX="$(yq -r '.toolkit.phase.tagPrefix // empty' "$CONFIG_FILE")"

if [[ "$PHASE_ENABLED" != "true" ]]; then
  log "Phase tagging disabled → skip changelog generation"
  exit 0
fi

if [[ -z "$TAG_PREFIX" ]]; then
  echo "❌ toolkit.phase.tagPrefix is empty in $CONFIG_FILE"
  exit 1
fi

############################################
# LIST TAGS
############################################
TAGS="$(git tag --list "${TAG_PREFIX}-*" --sort=version:refname)"

if [[ -z "$TAGS" ]]; then
  run_cmd echo "⚠️ No tags found with prefix ${TAG_PREFIX}"
  exit 0
fi

############################################
# INIT CHANGELOG
############################################
cp "$TEMPLATE" "$OUTPUT"
echo "" >> "$OUTPUT"

############################################
# GENERATE CHANGELOG
############################################
PREV_TAG=""

for TAG in $TAGS; do
  TITLE="$(git tag -l "$TAG" -n99 | sed "s/^${TAG}[[:space:]]*//")"

  echo "## $TITLE" >> "$OUTPUT"
  echo "" >> "$OUTPUT"

  if [[ -n "$PREV_TAG" ]]; then
    RANGE="${PREV_TAG}..${TAG}"
  else
    RANGE="$TAG"
  fi

  run_cmd git log "$RANGE" \
    --pretty=format:"- %s" \
    --no-merges >> "$OUTPUT"

  echo "" >> "$OUTPUT"

  PREV_TAG="$TAG"
done

log "✅ CHANGELOG.md generated at $OUTPUT"
