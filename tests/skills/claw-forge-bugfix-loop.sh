#!/usr/bin/env sh
# Structural fixture for skills/claw-forge-bugfix-loop/SKILL.md
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$REPO_ROOT/skills/claw-forge-bugfix-loop/SKILL.md"

. "$REPO_ROOT/tests/skills/lib/assert.sh"

assert_file_exists          "$SKILL"
assert_frontmatter_field    "$SKILL" name
assert_frontmatter_field    "$SKILL" description
assert_frontmatter_field    "$SKILL" triggers
assert_section              "$SKILL" "## Overview"
assert_section              "$SKILL" "## Steps"
assert_keyword              "$SKILL" "claw-forge state get"
assert_keyword              "$SKILL" "HANDOFF.md"
assert_keyword              "$SKILL" "bugfix-task"

check_result "claw-forge-bugfix-loop"
