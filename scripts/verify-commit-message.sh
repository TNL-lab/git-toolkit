#!/usr/bin/env bash
set -e

COMMIT_MSG_FILE="$1"
COMMIT_MSG="$(cat "$COMMIT_MSG_FILE")"

PATTERN='^(feat|fix|docs|test|refactor|chore|style)\([a-zA-Z0-9_-]+\)(\[phase-[0-9]+\])?: .+'

if [[ ! "$COMMIT_MSG" =~ $PATTERN ]]; then
  echo "❌ Invalid commit message format"
  echo ""
  echo "Expected format:"
  echo "  <type>(<scope>)[phase-x]: <Verb> <what>"
  echo ""
  echo "Example:"
  echo "  feat(context)[phase-1]: Add ContextStore"
  exit 1
fi

echo "✅ Commit message validated"