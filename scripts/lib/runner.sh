#!/usr/bin/env bash
set -euo pipefail

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "🟡 DRY-RUN: $*"
  else
    echo "▶ RUN: $*"
    "$@"
  fi
}