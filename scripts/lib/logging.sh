is_dry_run() {
  yq '.release.dryRun' .git-toolkit.yml | grep -q true
}

run_or_echo() {
  if is_dry_run; then
    echo "🟡 DRY-RUN: $*"
  else
    eval "$@"
  fi
}
