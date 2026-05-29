#!/usr/bin/env sh
# Structural fixture for skills/claw-forge-spec-authoring/SKILL.md
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$REPO_ROOT/skills/claw-forge-spec-authoring/SKILL.md"

. "$REPO_ROOT/tests/skills/lib/assert.sh"

assert_file_exists          "$SKILL"
assert_frontmatter_field    "$SKILL" name
assert_frontmatter_field    "$SKILL" description
assert_frontmatter_field    "$SKILL" triggers
assert_section              "$SKILL" "## Overview"
assert_section              "$SKILL" "## Steps"
assert_keyword              "$SKILL" "app_spec.xml"
assert_keyword              "$SKILL" "shape"
assert_keyword              "$SKILL" "spec-create"
assert_keyword              "$SKILL" "spec-fix"

check_result "claw-forge-spec-authoring"
