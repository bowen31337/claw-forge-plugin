#!/usr/bin/env sh
# Structural fixture for skills/claw-forge-boundaries-refactor/SKILL.md
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$REPO_ROOT/skills/claw-forge-boundaries-refactor/SKILL.md"

. "$REPO_ROOT/tests/skills/lib/assert.sh"

assert_file_exists          "$SKILL"
assert_frontmatter_field    "$SKILL" name
assert_frontmatter_field    "$SKILL" description
assert_frontmatter_field    "$SKILL" triggers
assert_section              "$SKILL" "## Overview"
assert_section              "$SKILL" "## Steps"
assert_keyword              "$SKILL" "hotspot"
assert_keyword              "$SKILL" "refactor"
assert_keyword              "$SKILL" "boundaries-apply"

check_result "claw-forge-boundaries-refactor"
