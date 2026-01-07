#!/usr/bin/env bash
set -euo pipefail

############################################
# ARGS
############################################
COMMIT_MSG_FILE="${1:-}"

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

############################################
# REPO & CONFIG
############################################
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [[ -n "${TOOLKIT_ROOT:-}" ]]; then
  TOOLKIT_DIR="$(cd "$TOOLKIT_ROOT" && pwd)"
else
  TOOLKIT_DIR="$REPO_ROOT"
fi

CONFIG_FILE="$REPO_ROOT/.git-toolkit.yml"

if [[ -n "${TOOLKIT_SCRIPTS:-}" ]]; then
  SCRIPT_DIR="$(cd "$TOOLKIT_SCRIPTS" && pwd)"
else
  SCRIPT_DIR="$TOOLKIT_DIR/scripts"
fi

[[ -f "$CONFIG_FILE" ]] || {
  echo "❌ Missing $CONFIG_FILE at repo root"
  exit 1
}

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/runner.sh"
source "$SCRIPT_DIR/lib/packages.sh"

############################################
# LOAD ALLOWED TYPES/SCOPES/PHASE
############################################
readarray -t ALLOWED_TYPES < <(yq -r '.commit.types.allowed[]' "$CONFIG_FILE" || true)
readarray -t ALLOWED_SCOPES < <(yq -r '.commit.scopes.allowed[]' "$CONFIG_FILE" || true)

PHASE_REQUIRED=$(yq -r '.toolkit.phase.required // false' "$CONFIG_FILE" || echo false)
PHASE_PATTERN=$(yq -r '.toolkit.phase.pattern // ""' "$CONFIG_FILE" || echo "")

# Strip ^/$ if present
PHASE_PATTERN="${PHASE_PATTERN#^}"
PHASE_PATTERN="${PHASE_PATTERN%$}"

# Build regex
TYPE_REGEX=$(IFS="|"; echo "${ALLOWED_TYPES[*]}")
SCOPE_REGEX=$(IFS="|"; echo "${ALLOWED_SCOPES[*]}")

if [[ "$PHASE_REQUIRED" == "true" ]]; then
  PHASE_PART="\\[(${PHASE_PATTERN})\\]"
else
  PHASE_PART="(\\[(${PHASE_PATTERN})\\])?"
fi

COMMIT_REGEX="^(${TYPE_REGEX})\\((${SCOPE_REGEX})\\)${PHASE_PART}: .*$"

############################################
# VALIDATE COMMIT MESSAGE
############################################
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

############################################
# VALIDATE TYPE
############################################
if [[ ! " ${ALLOWED_TYPES[*]} " =~ " $TYPE " ]]; then
  echo "❌ Invalid commit type: $TYPE"
  echo "Allowed: ${ALLOWED_TYPES[*]}"
  exit 1
fi

############################################
# VALIDATE SCOPE
############################################
if [[ ! " ${ALLOWED_SCOPES[*]} " =~ " $SCOPE " ]]; then
  echo "❌ Invalid commit scope: $SCOPE"
  echo "Allowed: ${ALLOWED_SCOPES[*]}"
  exit 1
fi

############################################
# VALIDATE PHASE
############################################
if [[ "$PHASE_REQUIRED" == "true" && -z "$PHASE" ]]; then
  echo "❌ Phase is required but missing"
  exit 1
fi

if [[ -n "$PHASE" && ! "$PHASE" =~ $PHASE_PATTERN ]]; then
  echo "❌ Invalid phase format: $PHASE"
  echo "Expected pattern: $PHASE_PATTERN"
  exit 1
fi

log "✅ Commit message validated against .git-toolkit.yml"
