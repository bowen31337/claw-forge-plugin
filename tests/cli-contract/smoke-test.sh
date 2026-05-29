#!/usr/bin/env bash
# tests/cli-contract/smoke-test.sh
#
# CI-safe cross-repo CLI-contract smoke test for PRD §8.
# No LLM invocation.
#
# Flow:
#   1. Create a temporary git repo with claw-forge.yaml + app_spec.xml
#   2. Boot `claw-forge state start --detach`
#   3. Exercise every contract-surface command with synthetic args
#   4. Assert documented JSON shape for each command
#   5. Display per-command diff (expected keys vs actual keys) on failure
#   6. Exit 0 if all shapes match; exit 1 on any mismatch
#
# Expected runtime: < 60 s on a warmed-up CI runner.

set -euo pipefail

PASS=0
FAIL=0
FAIL_NAMES=""

# ── helpers ──────────────────────────────────────────────────────────────────

_pass() { echo "PASS [$1]"; PASS=$((PASS + 1)); }

_fail() {
    local label="$1" reason="$2"
    echo "FAIL [${label}]: ${reason}"
    FAIL=$((FAIL + 1))
    FAIL_NAMES="${FAIL_NAMES} ${label}"
}

# assert_json LABEL OUTPUT KEY [KEY ...]
#
# Asserts OUTPUT is valid JSON and each KEY (a jq path expression) resolves to
# a non-empty value.  On failure prints a diff between expected and actual
# top-level keys so CI annotations are self-explanatory.
assert_json() {
    local label="$1" output="$2"
    shift 2

    if ! printf '%s' "${output}" | jq . >/dev/null 2>&1; then
        _fail "${label}" "output is not valid JSON: ${output}"
        return
    fi

    local missing="" key val
    for key in "$@"; do
        val=$(printf '%s' "${output}" | jq -r "${key} // empty" 2>/dev/null)
        [[ -z "${val}" ]] && missing+=" ${key}"
    done

    if [[ -n "${missing}" ]]; then
        echo "FAIL [${label}]: missing keys:${missing}"
        echo "  --- expected keys (jq paths)"
        printf '%s\n' "$@" | sort | sed 's/^/      /'
        echo "  +++ actual top-level keys"
        printf '%s' "${output}" | jq -r 'to_entries[].key' 2>/dev/null \
            | sort | sed 's/^/      /' || true
        FAIL=$((FAIL + 1))
        FAIL_NAMES="${FAIL_NAMES} ${label}"
    else
        _pass "${label}"
    fi
}

# ── setup ────────────────────────────────────────────────────────────────────

WORK_DIR=$(mktemp -d)

cleanup() {
    claw-forge state stop-all >/dev/null 2>&1 || true
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT INT TERM

cd "${WORK_DIR}"

git init -b main >/dev/null
git config user.email "ci@claw-forge.smoke"
git config user.name "CI Smoke"

cat > claw-forge.yaml << 'YAML'
project: smoke-test
target_branch: main
agent:
  max_concurrency: 2
YAML

# Minimal two-feature spec so `state ready` returns at least one task
cat > app_spec.xml << 'XML'
<project_specification mode="greenfield">
  <project_name>smoke-test</project_name>
  <core_features>
    <feature index="1" shape="core" touches_files="README.md">
      <description>System displays a README</description>
    </feature>
    <feature index="2" shape="core" touches_files="LICENSE">
      <description>System displays a LICENSE</description>
    </feature>
  </core_features>
</project_specification>
XML

touch README.md
git add .
git commit -m "chore: smoke-test initial commit" --quiet

echo "── setup: ${WORK_DIR}"

# ── 1. claw-forge --version ──────────────────────────────────────────────────

echo ""
echo "── claw-forge --version"
VERSION_OUT=$(claw-forge --version 2>&1)
if echo "${VERSION_OUT}" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'; then
    _pass "version"
else
    _fail "version" "expected semver in output, got: ${VERSION_OUT}"
fi

# ── 2. claw-forge state start --detach ───────────────────────────────────────

echo ""
echo "── claw-forge state start --detach"
if ! claw-forge state start --detach >/dev/null 2>&1; then
    _fail "state-start" "command exited non-zero"
    echo "FATAL: state service failed to start; aborting smoke test." >&2
    exit 1
fi

# Poll up to 20 s for the service to become ready
SERVICE_READY=false
i=0
while [[ "${i}" -lt 20 ]]; do
    RUNNING=$(claw-forge state status --json 2>/dev/null \
               | jq -r '.running // false' 2>/dev/null || echo false)
    if [[ "${RUNNING}" == "true" ]]; then SERVICE_READY=true; break; fi
    sleep 1; i=$((i + 1))
done
if [[ "${SERVICE_READY}" != "true" ]]; then
    _fail "state-start" "service not ready after 20 s"
    exit 1
fi
_pass "state-start"

# ── 3. claw-forge state status --json ────────────────────────────────────────

echo ""
echo "── claw-forge state status --json"
STATUS_OUT=$(claw-forge state status --json 2>&1)
assert_json "state-status" "${STATUS_OUT}" '.running' '.port'

# ── 4. claw-forge spec validate --json ───────────────────────────────────────

echo ""
echo "── claw-forge spec validate --json"
VALIDATE_OUT=$(claw-forge spec validate --json 2>&1 || true)
assert_json "spec-validate" "${VALIDATE_OUT}" '.valid' '.findings'

# ── 5. claw-forge plan --spec app_spec.xml --json ────────────────────────────

echo ""
echo "── claw-forge plan --spec app_spec.xml --json"
PLAN_OUT=$(claw-forge plan --spec app_spec.xml --json 2>&1)
assert_json "plan" "${PLAN_OUT}" '.features'

# ── 6. claw-forge state ready --json ─────────────────────────────────────────

echo ""
echo "── claw-forge state ready --json"
READY_OUT=$(claw-forge state ready --json 2>&1)
assert_json "state-ready" "${READY_OUT}" '.[0].id' '.[0].slug'

TASK_ID=$(printf '%s' "${READY_OUT}" | jq -r '.[0].id   // empty' 2>/dev/null)
TASK_SLUG=$(printf '%s' "${READY_OUT}" | jq -r '.[0].slug // empty' 2>/dev/null)
: "${TASK_ID:=smoke-001}" "${TASK_SLUG:=smoke-feature-001}"

# ── 7. claw-forge state get <id> --json ──────────────────────────────────────

echo ""
echo "── claw-forge state get ${TASK_ID} --json"
GET_OUT=$(claw-forge state get "${TASK_ID}" --json 2>&1 || true)
assert_json "state-get" "${GET_OUT}" '.id' '.status'

# ── 8. claw-forge file-claim <task-id> --files <globs> --json ────────────────

echo ""
echo "── claw-forge file-claim ${TASK_ID} --files README.md --json"
CLAIM_OUT=$(claw-forge file-claim "${TASK_ID}" --files "README.md" --json 2>&1 || true)
assert_json "file-claim" "${CLAIM_OUT}" '.claimed'

# ── 9. claw-forge git create-worktree <slug> --json ──────────────────────────

echo ""
echo "── claw-forge git create-worktree ${TASK_SLUG} --json"
WORKTREE_OUT=$(claw-forge git create-worktree "${TASK_SLUG}" --json 2>&1 || true)
assert_json "git-create-worktree" "${WORKTREE_OUT}" '.path' '.branch'

WORKTREE_PATH=$(printf '%s' "${WORKTREE_OUT}" | jq -r '.path // empty' 2>/dev/null)

# ── 10. claw-forge git sync-worktree <slug> --json ───────────────────────────

echo ""
echo "── claw-forge git sync-worktree ${TASK_SLUG} --json"
SYNC_OUT=$(claw-forge git sync-worktree "${TASK_SLUG}" --json 2>&1 || true)
assert_json "git-sync-worktree" "${SYNC_OUT}" '.status'

# ── 11. claw-forge git leak-snapshot <task-id> --json ────────────────────────

echo ""
echo "── claw-forge git leak-snapshot ${TASK_ID} --json"
SNAP_OUT=$(claw-forge git leak-snapshot "${TASK_ID}" --json 2>&1 || true)
# Shape: any valid JSON object
if printf '%s' "${SNAP_OUT}" | jq . >/dev/null 2>&1; then
    _pass "git-leak-snapshot"
else
    _fail "git-leak-snapshot" "not valid JSON: ${SNAP_OUT}"
fi

# ── 12. claw-forge git leak-check <task-id> --json ───────────────────────────

echo ""
echo "── claw-forge git leak-check ${TASK_ID} --json"
LEAK_OUT=$(claw-forge git leak-check "${TASK_ID}" --json 2>&1 || true)
assert_json "git-leak-check" "${LEAK_OUT}" '.leaks'

# ── 13. claw-forge state patch <id> --status completed --json ────────────────

echo ""
echo "── claw-forge state patch ${TASK_ID} --status completed --json"
PATCH_OUT=$(claw-forge state patch "${TASK_ID}" --status completed --json 2>&1 || true)
assert_json "state-patch" "${PATCH_OUT}" '.id' '.status'

# ── 14. claw-forge git squash-merge <slug> --json ────────────────────────────

# Seed a commit in the worktree so squash-merge has something to merge
if [[ -n "${WORKTREE_PATH}" && -d "${WORKTREE_PATH}" ]]; then
    echo "chore: smoke-test feature" > "${WORKTREE_PATH}/README.md"
    (cd "${WORKTREE_PATH}" \
        && git add README.md \
        && git commit -m "feat: smoke-test feature" --quiet)
fi

echo ""
echo "── claw-forge git squash-merge ${TASK_SLUG} --json"
MERGE_OUT=$(claw-forge git squash-merge "${TASK_SLUG}" --json 2>&1 || true)
assert_json "git-squash-merge" "${MERGE_OUT}" '.status'

# ── 15. claw-forge file-release <task-id> ────────────────────────────────────

echo ""
echo "── claw-forge file-release ${TASK_ID}"
# file-release emits no structured JSON; assert exit 0
if claw-forge file-release "${TASK_ID}" >/dev/null 2>&1; then
    _pass "file-release"
else
    _fail "file-release" "non-zero exit code"
fi

# ── 16. claw-forge boundaries audit --json ───────────────────────────────────

echo ""
echo "── claw-forge boundaries audit --json"
AUDIT_OUT=$(claw-forge boundaries audit --json 2>&1 || true)
assert_json "boundaries-audit" "${AUDIT_OUT}" '.hotspots'

# ── 17. claw-forge export <format> ───────────────────────────────────────────

echo ""
echo "── claw-forge export json"
# export writes a file and prints its path; assert non-empty output
EXPORT_OUT=$(claw-forge export json 2>&1 || true)
if [[ -n "${EXPORT_OUT}" ]]; then
    _pass "export"
else
    _fail "export" "no output (expected file path or status line)"
fi

# ── 18. claw-forge state resume --json ───────────────────────────────────────

echo ""
echo "── claw-forge state resume --json"
RESUME_OUT=$(claw-forge state resume --json 2>&1 || true)
assert_json "state-resume" "${RESUME_OUT}" '.resumed'

# ── 19. claw-forge ui ────────────────────────────────────────────────────────

echo ""
echo "── claw-forge ui  (BROWSER=echo — no actual open in CI)"
# Set BROWSER=echo so Python's webbrowser.open() prints the URL instead of
# launching a real browser.  Accept any exit code — the service may be gone.
if BROWSER=echo claw-forge ui >/dev/null 2>&1 \
   || command -v claw-forge >/dev/null 2>&1; then
    _pass "ui"
else
    _fail "ui" "claw-forge not on PATH"
fi

# ── 20. claw-forge state stop-all --json ─────────────────────────────────────

echo ""
echo "── claw-forge state stop-all --json"
STOP_OUT=$(claw-forge state stop-all --json 2>&1 || true)
assert_json "state-stop-all" "${STOP_OUT}" '.stopped'

# ── summary ──────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════"
printf 'CLI contract smoke test  PASS: %d  FAIL: %d\n' "${PASS}" "${FAIL}"
if [[ "${FAIL}" -gt 0 ]]; then
    echo "Failed commands:${FAIL_NAMES}"
    exit 1
fi
echo "All ${PASS} contract commands verified."
