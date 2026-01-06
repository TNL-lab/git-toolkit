#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [[ -n "${TOOLKIT_ROOT:-}" ]]; then
  TOOLKIT_DIR="$(cd "$TOOLKIT_ROOT" && pwd)"
else
  TOOLKIT_DIR="$REPO_ROOT"
fi

# Root config file
CONFIG_FILE=".git-toolkit.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

# Load release dry-run flag (default: false)
DRY_RUN="$(yq -r '.release.dryRun // false' "$CONFIG_FILE")"

# Normalize to strict boolean
if [[ "$DRY_RUN" != "true" && "$DRY_RUN" != "false" ]]; then
  echo "❌ Invalid value for release.dryRun (expected true/false)"
  exit 1
fi

export DRY_RUN
