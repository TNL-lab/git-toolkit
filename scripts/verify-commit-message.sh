#!/usr/bin/env bash
set -euo pipefail

COMMIT_MSG_FILE="${1:-}"

#1 Read commit message (file or stdin)
if [[ "$COMMIT_MSG_FILE" == "-" ]]; then
  COMMIT_MSG=$(cat)
elif [[ -f "$COMMIT_MSG_FILE" ]]; then
  COMMIT_MSG=$(sed -n '1p' "$COMMIT_MSG_FILE")
else
  echo "❌ Invalid input for commit message"
  exit 1
fi

COMMIT_MSG=$(echo "$COMMIT_MSG" | tr -d '\n')

#Locate repo root & config file
REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_FILE="$REPO_ROOT/.git-toolkit.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Missing .git-toolkit.yml at repo root"
  exit 1
fi

#Read config (SAFE)
readarray -t ALLOWED_TYPES < <(
  awk '/allowed_types:/,/^[^ ]/' "$CONFIG_FILE" | grep "-" | awk '{print $2}'
)

readarray -t ALLOWED_SCOPES < <(
  awk '/allowed_scopes:/,/^[^ ]/' "$CONFIG_FILE" | grep "-" | awk '{print $2}'
)

PHASE_REQUIRED=$(awk '/required:/ {print $2; exit}' "$CONFIG_FILE")
PHASE_PATTERN=$(awk '/pattern:/ {gsub(/"/,"",$2); print $2; exit}' "$CONFIG_FILE")

# Strip ^ and $ if present
PHASE_PATTERN="${PHASE_PATTERN#^}"
PHASE_PATTERN="${PHASE_PATTERN%$}"

#Build regex
TYPE_REGEX=$(IFS="|"; echo "${ALLOWED_TYPES[*]}")
SCOPE_REGEX=$(IFS="|"; echo "${ALLOWED_SCOPES[*]}")

if [[ "$PHASE_REQUIRED" == "true" ]]; then
  PHASE_PART="\[(${PHASE_PATTERN})\]"
else
  PHASE_PART="(\[(${PHASE_PATTERN})\])?"
fi

COMMIT_REGEX="^(${TYPE_REGEX})\\((${SCOPE_REGEX})\\)${PHASE_PART}: [A-Z][^ ]+.*$"

#Validate base format
if [[ ! "$COMMIT_MSG" =~ $COMMIT_REGEX ]]; then
   echo "❌ Commit message does not match required format"
  echo ""
  echo "Expected:"
  echo "<type>(<scope>)[phase-x]: <Verb> <what>"
  echo ""
  echo "Actual:"
  echo "$COMMIT_MSG"
  exit 1
fi

TYPE="${BASH_REMATCH[1]}"
SCOPE="${BASH_REMATCH[2]}"
PHASE="${BASH_REMATCH[3]:-}"

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