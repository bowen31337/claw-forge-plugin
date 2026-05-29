#!/usr/bin/env sh
# Structural fixture for skills/claw-forge-conflict-recovery/SKILL.md
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$REPO_ROOT/skills/claw-forge-conflict-recovery/SKILL.md"

. "$REPO_ROOT/tests/skills/lib/assert.sh"

assert_file_exists          "$SKILL"
assert_frontmatter_field    "$SKILL" name
assert_frontmatter_field    "$SKILL" description
assert_frontmatter_field    "$SKILL" triggers
assert_section              "$SKILL" "## Overview"
assert_section              "$SKILL" "## Steps"
assert_keyword              "$SKILL" "conflict"
assert_keyword              "$SKILL" "sync_conflict"
assert_keyword              "$SKILL" "resolution"

check_result "claw-forge-conflict-recovery"
