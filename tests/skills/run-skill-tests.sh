#!/usr/bin/env sh
# Skill structural self-tests — no LLM invocation.
# Reads each *.fixture file in this directory, then asserts:
#   1. The target SKILL.md exists.
#   2. Required YAML frontmatter fields are present (between the first pair of --- lines).
#   3. Required markdown section headings are present (exact ## text).
#   4. Required trigger keywords appear verbatim anywhere in the file.
#
# Exits 0 on all green, 1 on any failure.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"

pass_count=0
fail_count=0

# Helpers -------------------------------------------------------------------

frontmatter_has_field() {
    # Returns 0 if $2 is a YAML key in the first frontmatter block of $1.
    local file="$1"
    local field="$2"
    awk -v field="$field" '
        BEGIN { in_fm=0; found=0 }
        /^---/ { in_fm++; if (in_fm >= 2) exit; next }
        in_fm == 1 && $0 ~ "^" field "[[:space:]]*:" { found=1 }
        END { exit (found ? 0 : 1) }
    ' "$file"
}

file_has_section() {
    # Returns 0 if $2 appears as an exact line in $1.
    local file="$1"
    local section="$2"
    grep -qF "$section" "$file"
}

file_has_keyword() {
    # Returns 0 if $2 appears verbatim anywhere in $1 (not anchored to line start).
    local file="$1"
    local keyword="$2"
    grep -qF "$keyword" "$file"
}

assert_pass() {
    pass_count=$((pass_count + 1))
    printf '  [PASS] %s\n' "$1"
}

assert_fail() {
    fail_count=$((fail_count + 1))
    printf '  [FAIL] %s\n' "$1"
}

# Main loop -----------------------------------------------------------------

for fixture in "$FIXTURES_DIR"/*.fixture; do
    # Skip if no fixtures found (glob literal)
    [ -e "$fixture" ] || continue

    skill_name="$(basename "$fixture" .fixture)"
    printf '\nskill: %s\n' "$skill_name"

    skill_file=""
    while IFS=': ' read -r directive value; do
        # Strip leading/trailing whitespace from value
        value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"

        case "$directive" in
            \#* | '') continue ;;  # comment or blank

            skill_file)
                skill_file="${REPO_ROOT}/${value}"
                if [ -f "$skill_file" ]; then
                    assert_pass "file exists: ${value}"
                else
                    assert_fail "file exists: ${value} (not found)"
                    skill_file=""  # skip remaining checks for this fixture
                fi
                ;;

            require_frontmatter)
                if [ -z "$skill_file" ]; then continue; fi
                if frontmatter_has_field "$skill_file" "$value"; then
                    assert_pass "frontmatter field: ${value}"
                else
                    assert_fail "frontmatter field: ${value} (missing)"
                fi
                ;;

            require_section)
                if [ -z "$skill_file" ]; then continue; fi
                if file_has_section "$skill_file" "$value"; then
                    assert_pass "section: ${value}"
                else
                    assert_fail "section: ${value} (not found)"
                fi
                ;;

            require_keyword)
                if [ -z "$skill_file" ]; then continue; fi
                if file_has_keyword "$skill_file" "$value"; then
                    assert_pass "keyword: ${value}"
                else
                    assert_fail "keyword: ${value} (not found)"
                fi
                ;;
        esac
    done < "$fixture"
done

# Summary -------------------------------------------------------------------

printf '\n'
total=$((pass_count + fail_count))
printf 'Results: %d assertion(s), %d passed, %d failed\n' \
    "$total" "$pass_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
exit 0
