#!/usr/bin/env bash
set -euo pipefail

COMMIT_MSG_FILE="$1"
COMMIT_MSG="$(head -n 1 "$COMMIT_MSG_FILE")"

REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_FILE="$REPO_ROOT/.git-toolkit.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Missing .git-toolkit.yml at repo root"
  exit 1
fi

##READ ALLOWED TYPES FROM CONFIG FILE
readarray -t ALLOWED_TYPES < <(
  grep -A20 "^commit:" "$CONFIG_FILE" \
  | grep "allowed_types" -A20 \
  | grep "-" \
  | awk '{print $2}'
)

##READ ALLOWED SCOPES FROM CONFIG FILE
readarray -t ALLOWED_SCOPES < <(
  grep -A20 "^commit:" "$CONFIG_FILE" \
  | grep "allowed_scopes" -A20 \
  | grep "-" \
  | awk '{print $2}'
)

##READ REQUIRED PHASE
PHASE_REQUIRED=$(grep "required:" "$CONFIG_FILE" | awk '{print $2}')
PHASE_PATTERN=$(grep "pattern:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')

##EXTRACT COMMIT MSG WITH REGEX
COMMIT_REGEX='^([a-z]+)\(([a-zA-Z0-9_-]+)\)(\[([^\]]+)\])?:'

if [[ ! "$COMMIT_MSG" =~ $COMMIT_REGEX ]]; then
  echo "❌ Commit message does not match base format"
  exit 1
fi

TYPE="${BASH_REMATCH[1]}"
SCOPE="${BASH_REMATCH[2]}"
PHASE="${BASH_REMATCH[4]:-}"

##VALIDATE TYPED
if [[ ! " ${ALLOWED_TYPES[*]} " =~ " $TYPE " ]]; then
  echo "❌ Invalid commit type: $TYPE"
  echo "Allowed: ${ALLOWED_TYPES[*]}"
  exit 1
fi

##VALIDATE SCOPES
if [[ ! " ${ALLOWED_SCOPES[*]} " =~ " $SCOPE " ]]; then
  echo "❌ Invalid commit scope: $SCOPE"
  echo "Allowed: ${ALLOWED_SCOPES[*]}"
  exit 1
fi

##Validate PHASE
##If phase is required, but not present
if [[ "$PHASE_REQUIRED" == "true" && -z "$PHASE" ]]; then
  echo "❌ Phase is required but missing"
  exit 1
fi

##If phase is present, validate format
if [[ -n "$PHASE" && ! "$PHASE" =~ $PHASE_PATTERN ]]; then
  echo "❌ Invalid phase format: $PHASE"
  echo "Expected pattern: $PHASE_PATTERN"
  exit 1
fi

echo "✅ Commit message validated against .git-toolkit.yml"



