#!/usr/bin/env bash
set -euo pipefail

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
