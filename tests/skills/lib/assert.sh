#!/usr/bin/env sh
# Shared assertion helpers for skill structural fixtures.
# Source this file; do not execute it directly.
#
# Usage in a fixture script:
#   . "$REPO_ROOT/tests/skills/lib/assert.sh"
#   assert_file_exists  "$SKILL"
#   assert_frontmatter_field "$SKILL" name
#   assert_section      "$SKILL" "## Steps"
#   assert_keyword      "$SKILL" "some keyword"
#   check_result "skill-name"   # prints summary; returns 0 or 1

_PASS=0
_FAIL=0

_ok() { printf '    ok  %s\n' "$*"; _PASS=$((_PASS + 1)); }
_ng() { printf '  FAIL  %s\n' "$*"; _FAIL=$((_FAIL + 1)); }

# assert_file_exists PATH
assert_file_exists() {
  if [ -f "$1" ]; then
    _ok "file exists: $1"
  else
    _ng "file missing: $1"
  fi
}

# _frontmatter FILE — print the YAML frontmatter body (between the first two --- lines)
_frontmatter() {
  awk 'NR==1 && /^---$/{fm=1; next} fm && /^---$/{exit} fm{print}' "$1" 2>/dev/null
}

# assert_frontmatter_field FILE FIELD
# Asserts that the frontmatter contains a line beginning with "field:"
assert_frontmatter_field() {
  local file="$1" field="$2"
  if [ ! -f "$file" ]; then
    _ng "frontmatter.$field: file missing ($file)"
    return
  fi
  if _frontmatter "$file" | grep -q "^${field}:"; then
    _ok "frontmatter.${field} present"
  else
    _ng "frontmatter.${field} missing"
  fi
}

# assert_section FILE HEADING
# Asserts that the file contains the exact heading string (e.g. "## Steps")
assert_section() {
  local file="$1" heading="$2"
  if [ ! -f "$file" ]; then
    _ng "section '${heading}': file missing ($file)"
    return
  fi
  if grep -qF "$heading" "$file"; then
    _ok "section present: ${heading}"
  else
    _ng "section missing: ${heading}"
  fi
}

# assert_keyword FILE KEYWORD
# Asserts that the keyword appears somewhere in the file (case-insensitive)
assert_keyword() {
  local file="$1" keyword="$2"
  if [ ! -f "$file" ]; then
    _ng "keyword '${keyword}': file missing ($file)"
    return
  fi
  if grep -qi "$keyword" "$file"; then
    _ok "keyword present: ${keyword}"
  else
    _ng "keyword missing: ${keyword}"
  fi
}

# check_result SKILL_NAME
# Prints a one-line pass/fail summary and returns 0 (all pass) or 1 (any fail).
check_result() {
  local name="$1"
  if [ "$_FAIL" -eq 0 ]; then
    printf 'PASS  %-45s (%d checks)\n' "$name" "$_PASS"
    return 0
  else
    printf 'FAIL  %-45s (%d/%d failed)\n' "$name" "$_FAIL" "$((_PASS + _FAIL))"
    return 1
  fi
}
