#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# Args
# -------------------------------------------------
COMMIT_MSG_FILE="${1:-}"

# Read commit message
if [[ "$COMMIT_MSG_FILE" == "-" ]]; then
  COMMIT_MSG=$(cat)
elif [[ -f "$COMMIT_MSG_FILE" ]]; then
  COMMIT_MSG=$(sed -n '1p' "$COMMIT_MSG_FILE")
else
  echo "❌ Invalid input for commit message"
  exit 1
fi

# Strip newlines
COMMIT_MSG="$(echo "$COMMIT_MSG" | tr -d '\n')"

# -------------------------------------------------
# Repo root & config
# -------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_FILE="$REPO_ROOT/.git-toolkit.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Missing $CONFIG_FILE at repo root"
  exit 1
fi

# -------------------------------------------------
# Load allowed types/scopes/phase
# -------------------------------------------------
readarray -t ALLOWED_TYPES < <(yq '.commit.allowed_types[]' "$CONFIG_FILE")
readarray -t ALLOWED_SCOPES < <(yq '.commit.allowed_scopes[]' "$CONFIG_FILE")

PHASE_REQUIRED=$(yq '.toolkit.phase.required' "$CONFIG_FILE")
PHASE_PATTERN=$(yq -r '.toolkit.phase.pattern' "$CONFIG_FILE")

# Strip ^/$
PHASE_PATTERN="${PHASE_PATTERN#^}"
PHASE_PATTERN="${PHASE_PATTERN%$}"

# Build regex
TYPE_REGEX=$(IFS="|"; echo "${ALLOWED_TYPES[*]}")
SCOPE_REGEX=$(IFS="|"; echo "${ALLOWED_SCOPES[*]}")

if [[ "$PHASE_REQUIRED" == "true" ]]; then
  PHASE_PART="\[(${PHASE_PATTERN})\]"
else
  PHASE_PART="(\[(${PHASE_PATTERN})\])?"
fi

COMMIT_REGEX="^(${TYPE_REGEX})\\((${SCOPE_REGEX})\\)${PHASE_PART}: [A-Z][^ ]+.*$"

# -------------------------------------------------
# Validate commit message
# -------------------------------------------------
if [[ ! "$COMMIT_MSG" =~ $COMMIT_REGEX ]]; then
  echo "❌ Commit message does not match required format"
  echo ""
  echo "Expected format:"
  echo "<type>(<scope>)[phase-x]: <Verb> <what>"
  echo ""
  echo "Actual:"
  echo "$COMMIT_MSG"
  exit 1
fi

# Extract matched groups
TYPE="${BASH_REMATCH[1]}"
SCOPE="${BASH_REMATCH[2]}"
PHASE="${BASH_REMATCH[3]:-}"

# Validate TYPE
if [[ ! " ${ALLOWED_TYPES[*]} " =~ " $TYPE " ]]; then
  echo "❌ Invalid commit type: $TYPE"
  echo "Allowed: ${ALLOWED_TYPES[*]}"
  exit 1
fi

# Validate SCOPE
if [[ ! " ${ALLOWED_SCOPES[*]} " =~ " $SCOPE " ]]; then
  echo "❌ Invalid commit scope: $SCOPE"
  echo "Allowed: ${ALLOWED_SCOPES[*]}"
  exit 1
fi

# Validate PHASE
if [[ "$PHASE_REQUIRED" == "true" && -z "$PHASE" ]]; then
  echo "❌ Phase is required but missing"
  exit 1
fi

if [[ -n "$PHASE" && ! "$PHASE" =~ $PHASE_PATTERN ]]; then
  echo "❌ Invalid phase format: $PHASE"
  echo "Expected pattern: $PHASE_PATTERN"
  exit 1
fi

# Success
echo "✅ Commit message validated against .git-toolkit.yml"
