#!/usr/bin/env bash
set -euo pipefail

# Root of framework repo (assume scripts always run from repo root)
CONFIG_FILE=".git-toolkit.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Missing $CONFIG_FILE"
  exit 1
fi

# Load dry-run flag (default false)
DRY_RUN=$(yq '.release.dryRun // false' "$CONFIG_FILE")

export DRY_RUN