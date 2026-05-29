#!/usr/bin/env bash
# tests/skills/run-fixtures.sh
#
# Structural self-test for every skill under skills/.
# No LLM invocation — checks file presence, YAML frontmatter shape, and
# required section headings only.
#
# For each SKILL.md:
#   - File must exist (presence)
#   - If non-empty: must begin with "---" (frontmatter delimiter)
#   - If non-empty: frontmatter must contain "name:" and "description:"
#   - If non-empty: body must contain at least one "## " section heading
#
# Empty stub files pass the presence check with a WARN; full check is
# deferred until the skill body is authored.

set -euo pipefail

PASS=0; FAIL=0; FAIL_NAMES=""

EXPECTED_SKILLS=(
    claw-forge-dispatch-loop
    claw-forge-feature-implementation
    claw-forge-conflict-recovery
    claw-forge-boundaries-refactor
    claw-forge-spec-authoring
    claw-forge-bugfix-loop
)

_pass() { echo "PASS [$1]"; PASS=$((PASS + 1)); }
_fail() { echo "FAIL [$1]: $2"; FAIL=$((FAIL + 1)); FAIL_NAMES+=" $1"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for skill in "${EXPECTED_SKILLS[@]}"; do
    skill_file="${REPO_ROOT}/skills/${skill}/SKILL.md"

    # ── presence ──────────────────────────────────────────────────────────────
    if [[ ! -f "${skill_file}" ]]; then
        _fail "${skill}" "SKILL.md not found at skills/${skill}/SKILL.md"
        continue
    fi

    # ── empty stub: presence only ─────────────────────────────────────────────
    if [[ ! -s "${skill_file}" ]]; then
        echo "WARN [${skill}]: SKILL.md is empty (stub — full check deferred)"
        _pass "${skill} (presence)"
        continue
    fi

    # ── frontmatter delimiter ─────────────────────────────────────────────────
    if ! head -1 "${skill_file}" | grep -q '^---'; then
        _fail "${skill}" "SKILL.md does not start with YAML frontmatter (---)"
        continue
    fi

    # Extract the frontmatter block (lines between first and second ---)
    FRONTMATTER=$(awk '/^---/{p++; if(p==2) exit} p==1 && !/^---/' "${skill_file}")

    if ! echo "${FRONTMATTER}" | grep -q 'name:'; then
        _fail "${skill}" "frontmatter missing 'name:' field"
        continue
    fi
    if ! echo "${FRONTMATTER}" | grep -q 'description:'; then
        _fail "${skill}" "frontmatter missing 'description:' field"
        continue
    fi

    # ── at least one ## section heading in the body ───────────────────────────
    if ! grep -q '^## ' "${skill_file}"; then
        _fail "${skill}" "no '## ' section headings found in body"
        continue
    fi

    _pass "${skill}"
done

echo ""
printf 'Skill structural fixtures  PASS: %d  FAIL: %d\n' "${PASS}" "${FAIL}"
if [[ "${FAIL}" -gt 0 ]]; then
    echo "Failed:${FAIL_NAMES}"
    exit 1
fi
echo "All ${PASS} skills verified."
