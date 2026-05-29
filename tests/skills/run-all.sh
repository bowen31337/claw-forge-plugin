#!/usr/bin/env sh
# tests/skills/run-all.sh
# Run every per-skill structural fixture under tests/skills/.
# Exit 0 when all fixtures pass; exit 1 on any failure.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES_DIR="$REPO_ROOT/tests/skills"

total=0
passed=0
failed=0
failed_names=""

printf 'Skill structural fixtures\n'
printf '═══════════════════════════════════════════════════════\n'

for fixture in "$FIXTURES_DIR"/claw-forge-*.sh; do
  [ -f "$fixture" ] || continue
  skill="$(basename "$fixture" .sh)"
  printf '\n── %s\n' "$skill"
  if sh "$fixture"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    failed_names="$failed_names $skill"
  fi
  total=$((total + 1))
done

printf '\n═══════════════════════════════════════════════════════\n'

if [ "$total" -eq 0 ]; then
  printf 'No fixture scripts found under %s\n' "$FIXTURES_DIR"
  exit 1
fi

printf 'Result: %d/%d skills passed\n' "$passed" "$total"

if [ "$failed" -gt 0 ]; then
  printf 'Failed:%s\n' "$failed_names"
  exit 1
fi

printf 'All fixtures green.\n'
exit 0
