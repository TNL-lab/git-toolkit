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

# Read bump rules from config
MAJOR_KEYWORD=$(yq '.release.major_keyword' "$CONFIG_FILE")
BUMP_RULE_FEAT=$(yq '.release.bump_rules.feat // "minor"' "$CONFIG_FILE")
BUMP_RULE_FIX=$(yq '.release.bump_rules.fix // "patch"' "$CONFIG_FILE")

# Expect: toolkit-v1.2.3
if [[ ! "$TAG" =~ v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "❌ Invalid tag format. Expected <prefix>-vMAJOR.MINOR.PATCH"
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "💧 DRY-RUN mode: VERSION would be bumped to $VERSION"
  exit 0
fi

# Get previous tag
PREV_TAG=$(git describe --tags --abbrev=0 "$TAG"^ 2>/dev/null || echo "")

# Collect commits
if [[ -n "$PREV_TAG" ]]; then
  COMMITS=$(git log "$PREV_TAG..$TAG" --pretty=format:"%s")
else
  COMMITS=$(git log "$TAG" --pretty=format:"%s")
fi

# Determine bump type
BUMP_TYPE="none"
if grep -q "$MAJOR_KEYWORD" <<< "$COMMITS"; then
    BUMP_TYPE="major"
elif grep -q "^feat" <<< "$COMMITS"; then
    BUMP_TYPE="$BUMP_RULE_FEAT"
elif grep -q "^fix" <<< "$COMMITS"; then
    BUMP_TYPE="$BUMP_RULE_FIX"
fi

if [[ "$BUMP_TYPE" == "none" ]]; then
  echo "ℹ️ No version bump needed"
  exit 0
fi

# Apply bump
case "$BUMP_TYPE" in
  major)
    ((MAJOR++))
    MINOR=0
    PATCH=0
    ;;
  minor)
    ((MINOR++))
    PATCH=0
    ;;
  patch)
    ((PATCH++))
    ;;
  *)
    echo "❌ Unknown bump type: $BUMP_TYPE"
    exit 1
    ;;
esac

VERSION="$MAJOR.$MINOR.$PATCH"

echo "$VERSION" > "$VERSION_FILE"
echo "🔖 VERSION updated to $VERSION in $VERSION_FILE"

run_cmd git add "$VERSION_FILE"
run_cmd git commit -m "chore(release): bump version to $VERSION"
run_cmd git push origin HEAD

echo "✅ VERSION bump committed & pushed"
