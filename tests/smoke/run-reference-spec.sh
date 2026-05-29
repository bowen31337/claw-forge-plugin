#!/usr/bin/env bash
# tests/smoke/run-reference-spec.sh
#
# Manual end-to-end smoke test for claw-forge-plugin.
# Drives the plan → run → merge pipeline against the 5-feature todo-app
# reference spec and displays per-phase pass/fail status.
#
# WHY THIS IS NOT IN CI
# ─────────────────────
# The "run" phase dispatches real LLM subagents through an interactive
# Claude Code session. There is no way to drive that without `claude -p`
# (headless mode), and the plugin's hard invariant forbids `claude -p`
# anywhere in the plugin tree. This script is therefore run manually by a
# developer before each release. Automated CI covers only the sidecar CLI
# contract and static plugin checks (see CI/github-actions.yml).
#
# USAGE
# ─────
#   bash tests/smoke/run-reference-spec.sh
#   TIMEOUT_MIN=60 bash tests/smoke/run-reference-spec.sh   # extend run timeout
#
# PREREQUISITES
# ─────────────
#   claw-forge >= 0.6.0 on PATH   (pip install -U claw-forge)
#   git 2.30+ on PATH
#   jq on PATH
#
# EXIT CODES
#   0  all three phases passed
#   1  one or more phase checks failed or the run phase timed out

set -euo pipefail

# ─────────────────────────────────────────────
# Configuration (override via env vars)
# ─────────────────────────────────────────────
TIMEOUT_MIN="${TIMEOUT_MIN:-30}"       # minutes to wait for /claw-forge run
POLL_INTERVAL_SEC="${POLL_INTERVAL_SEC:-10}"
MIN_COMPLETION_RATE=85                 # ≥85% required — matches PRD §6

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/reference-specs/todo-app-5features/app_spec.xml"

# ─────────────────────────────────────────────
# Colour helpers (no-op when stdout is not a tty)
# ─────────────────────────────────────────────
if [ -t 1 ]; then
  C_GREEN='\033[0;32m'
  C_RED='\033[0;31m'
  C_YELLOW='\033[1;33m'
  C_BOLD='\033[1m'
  C_RESET='\033[0m'
else
  C_GREEN='' C_RED='' C_YELLOW='' C_BOLD='' C_RESET=''
fi

# ─────────────────────────────────────────────
# Counters and shared state
# ─────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
TEST_DIR=""
SIDECAR_STARTED=false
TASK_IDS=()
TASK_SLUGS=()

# ─────────────────────────────────────────────
# Output helpers
# ─────────────────────────────────────────────
pass() {
  printf "${C_GREEN}  [PASS]${C_RESET} %s\n" "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf "${C_RED}  [FAIL]${C_RESET} %s\n" "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

info() { printf "        %s\n" "$1"; }

banner() {
  printf "\n${C_BOLD}━━━ Phase %s: %s ━━━${C_RESET}\n" "$1" "$2"
}

# ─────────────────────────────────────────────
# Cleanup — always runs on exit, interrupt, or kill
# ─────────────────────────────────────────────
cleanup() {
  local exit_code=$?
  if $SIDECAR_STARTED && [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
    printf "\n        stopping sidecar state service...\n"
    (cd "$TEST_DIR" && claw-forge state stop 2>/dev/null \
      || claw-forge state stop-all --json 2>/dev/null \
      || true)
  fi
  if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

# ─────────────────────────────────────────────
# Preflight — check tools and fixture
# ─────────────────────────────────────────────
preflight() {
  printf "${C_BOLD}claw-forge-plugin smoke test — todo-app-5features${C_RESET}\n"
  printf "  fixture : %s\n" "$FIXTURE"
  printf "  timeout : %dm (run phase)\n\n" "$TIMEOUT_MIN"

  local ok=true

  if ! command -v claw-forge >/dev/null 2>&1; then
    printf "${C_RED}  error:${C_RESET} claw-forge not on PATH\n"
    printf "         Install: pip install -U 'claw-forge>=0.6.0'\n"
    ok=false
  fi

  if ! command -v jq >/dev/null 2>&1; then
    printf "${C_RED}  error:${C_RESET} jq not on PATH\n"
    ok=false
  fi

  if ! command -v git >/dev/null 2>&1; then
    printf "${C_RED}  error:${C_RESET} git not on PATH\n"
    ok=false
  fi

  if [ ! -f "$FIXTURE" ]; then
    printf "${C_RED}  error:${C_RESET} fixture not found: %s\n" "$FIXTURE"
    ok=false
  fi

  $ok || { printf "\nAborting: preflight failed.\n"; exit 1; }

  local ver
  ver="$(claw-forge --version 2>/dev/null | awk '{print $NF}' || echo 'unknown')"
  info "sidecar version: $ver"
}

# ─────────────────────────────────────────────
# Setup — create an isolated test project dir
# ─────────────────────────────────────────────
setup_project() {
  TEST_DIR="$(mktemp -d -t claw-forge-smoke-XXXXXX)"
  info "test directory: $TEST_DIR"

  # Minimal git repo — sidecar worktree helpers require an initialised repo.
  git -C "$TEST_DIR" init -q
  git -C "$TEST_DIR" symbolic-ref HEAD refs/heads/main
  git -C "$TEST_DIR" config user.email "smoke-test@claw-forge.local"
  git -C "$TEST_DIR" config user.name "claw-forge smoke"
  git -C "$TEST_DIR" commit --allow-empty -m "chore: smoke test root [skip ci]" -q

  # Copy the reference spec.
  cp "$FIXTURE" "$TEST_DIR/app_spec.xml"

  # Minimal claw-forge.yaml so the sidecar and SessionStart hook recognise
  # this as a claw-forge project.
  if [ -f "$REPO_ROOT/claw-forge.yaml" ]; then
    cp "$REPO_ROOT/claw-forge.yaml" "$TEST_DIR/claw-forge.yaml"
  else
    cat > "$TEST_DIR/claw-forge.yaml" <<'YAML'
git:
  target_branch: main
  branch_prefix: feat
  cleanup_orphan_worktrees: smart
agent:
  max_concurrency: 3
state:
  host: "127.0.0.1"
  port: 8420
YAML
  fi
}

# ─────────────────────────────────────────────
# Start sidecar state service
# ─────────────────────────────────────────────
start_sidecar() {
  info "starting sidecar state service..."
  (cd "$TEST_DIR" && claw-forge state start --detach 2>&1) || {
    printf "${C_RED}  error:${C_RESET} claw-forge state start failed.\n"
    printf "         Try manually: cd %s && claw-forge state start\n" "$TEST_DIR"
    exit 1
  }
  SIDECAR_STARTED=true

  # Wait up to 15 s for the service to report as running.
  local i=0 running="false"
  while [ "$i" -lt 15 ]; do
    running="$(cd "$TEST_DIR" \
      && claw-forge state status --json 2>/dev/null | jq -r '.running // "false"' \
      || echo "false")"
    [ "$running" = "true" ] && break
    sleep 1
    i=$((i + 1))
  done

  if [ "$running" != "true" ]; then
    printf "${C_RED}  error:${C_RESET} sidecar did not become ready within 15s.\n"
    exit 1
  fi

  info "sidecar ready"
}

# ─────────────────────────────────────────────
# Phase 1: plan
# ─────────────────────────────────────────────
phase_plan() {
  banner 1 "plan"

  local output
  if ! output="$(cd "$TEST_DIR" && claw-forge plan --spec app_spec.xml --json 2>&1)"; then
    fail "claw-forge plan exited non-zero"
    info "output: $output"
    return
  fi

  if ! echo "$output" | jq . >/dev/null 2>&1; then
    fail "plan output is not valid JSON"
    info "raw: $output"
    return
  fi

  # Populate TASK_IDS and TASK_SLUGS from the plan JSON.
  # Expected shape: {"tasks": [{"id": "...", "slug": "...", ...}, ...], ...}
  while IFS= read -r id; do
    [ -n "$id" ] && TASK_IDS+=("$id")
  done < <(echo "$output" | jq -r '.tasks[].id' 2>/dev/null || true)

  while IFS= read -r slug; do
    [ -n "$slug" ] && TASK_SLUGS+=("$slug")
  done < <(echo "$output" | jq -r '.tasks[].slug' 2>/dev/null || true)

  local count="${#TASK_IDS[@]}"

  if [ "$count" -eq 5 ]; then
    pass "seeded $count tasks into DAG"
  elif [ "$count" -gt 0 ]; then
    fail "expected 5 tasks, got $count"
  else
    fail "plan returned no tasks"
    info "plan output: $output"
    return
  fi

  # Verify every task starts in a pending or ready state.
  local bad=0
  for id in "${TASK_IDS[@]}"; do
    local status
    status="$(cd "$TEST_DIR" \
      && claw-forge state get "$id" --json 2>/dev/null | jq -r '.status' \
      || echo 'unknown')"
    case "$status" in
      pending|ready) ;;
      *) bad=$((bad + 1)); info "unexpected initial status for $id: $status" ;;
    esac
  done

  if [ "$bad" -eq 0 ]; then
    pass "all $count tasks in initial pending/ready state"
  else
    fail "$bad task(s) have unexpected initial status"
  fi
}

# ─────────────────────────────────────────────
# Phase 2: run (requires interactive Claude Code session)
# ─────────────────────────────────────────────
phase_run() {
  banner 2 "run"

  if [ "${#TASK_IDS[@]}" -eq 0 ]; then
    fail "no task IDs available — plan phase must pass before run"
    return
  fi

  printf "\n"
  printf "${C_YELLOW}  ► Action required${C_RESET} — open Claude Code in the test project and run:\n\n"
  printf "      cd %s\n" "$TEST_DIR"
  printf "      claude                 # opens an interactive session\n"
  printf "      /claw-forge run        # type this slash command inside claude\n\n"
  printf "  Polling sidecar every %ds; timeout %dm. Ctrl-C to abort.\n\n" \
    "$POLL_INTERVAL_SEC" "$TIMEOUT_MIN"

  local total="${#TASK_IDS[@]}"
  local deadline=$(( $(date +%s) + TIMEOUT_MIN * 60 ))
  local run_seen=false

  while true; do
    local completed=0 failed=0 running=0 other=0

    for id in "${TASK_IDS[@]}"; do
      local status
      status="$(cd "$TEST_DIR" \
        && claw-forge state get "$id" --json 2>/dev/null \
        | jq -r '.status // "unknown"' \
        || echo 'unknown')"
      case "$status" in
        completed) completed=$((completed + 1)) ;;
        failed)    failed=$((failed + 1)) ;;
        running)   running=$((running + 1)); run_seen=true ;;
        *)         other=$((other + 1)) ;;
      esac
    done

    local terminal=$(( completed + failed ))

    # All tasks have reached a terminal state — evaluate completion rate.
    if [ "$terminal" -eq "$total" ]; then
      local rate=$(( completed * 100 / total ))
      if [ "$rate" -ge "$MIN_COMPLETION_RATE" ]; then
        pass "completion rate: $completed/$total (${rate}%) — target ≥${MIN_COMPLETION_RATE}%"
      else
        fail "completion rate: $completed/$total (${rate}%) — below ${MIN_COMPLETION_RATE}% target"
        info "per-task status:"
        for id in "${TASK_IDS[@]}"; do
          local row
          row="$(cd "$TEST_DIR" \
            && claw-forge state get "$id" --json 2>/dev/null \
            | jq -r '"  " + .id + "  " + .status + "  (" + (.slug // "?") + ")"' \
            || echo "  $id  unknown")"
          info "$row"
        done
      fi
      break
    fi

    # Timeout guard.
    if [ "$(date +%s)" -ge "$deadline" ]; then
      fail "run phase timed out after ${TIMEOUT_MIN}m ($completed/$total complete, $failed failed)"
      break
    fi

    # Progress line — overwrite in place when connected to a terminal.
    if [ -t 1 ]; then
      printf "  ...%d/%d done  %d running  %d pending/other  %d failed\r" \
        "$completed" "$total" "$running" "$other" "$failed"
    else
      if ! $run_seen && [ "$running" -eq 0 ] && [ "$terminal" -eq 0 ]; then
        printf "  waiting for /claw-forge run to start...\n"
      else
        printf "  %d/%d done  %d running  %d failed\n" \
          "$completed" "$total" "$running" "$failed"
      fi
    fi

    sleep "$POLL_INTERVAL_SEC"
  done
  printf "\n"
}

# ─────────────────────────────────────────────
# Phase 3: merge
# ─────────────────────────────────────────────
phase_merge() {
  banner 3 "merge"

  if [ "${#TASK_SLUGS[@]}" -eq 0 ]; then
    fail "no task slugs available — plan phase must pass before merge"
    return
  fi

  local total="${#TASK_SLUGS[@]}"
  local merged=0 skipped=0 errors=0

  for slug in "${TASK_SLUGS[@]}"; do
    local result
    result="$(cd "$TEST_DIR" \
      && claw-forge git squash-merge "$slug" --json 2>&1 \
      || echo '{"status":"error","error":"non-zero exit"}')"

    if ! echo "$result" | jq . >/dev/null 2>&1; then
      errors=$((errors + 1))
      info "merge $slug: non-JSON output — $result"
      continue
    fi

    local status
    status="$(echo "$result" | jq -r '.status // "unknown"')"
    case "$status" in
      success|already_merged)
        merged=$((merged + 1))
        ;;
      not_ready|skipped|task_not_completed)
        # Feature did not complete — expected when completion rate < 100%.
        skipped=$((skipped + 1))
        info "merge $slug: $status (feature did not complete)"
        ;;
      conflict)
        errors=$((errors + 1))
        local detail
        detail="$(echo "$result" | jq -r '.error // "conflict"')"
        info "merge $slug: conflict — $detail"
        ;;
      *)
        errors=$((errors + 1))
        local detail
        detail="$(echo "$result" | jq -r '.error // .status')"
        info "merge $slug: $status — $detail"
        ;;
    esac
  done

  local threshold=$(( total * MIN_COMPLETION_RATE / 100 ))

  if [ "$errors" -eq 0 ]; then
    pass "merged $merged/$total branches ($skipped skipped — feature did not complete)"
  elif [ "$merged" -ge "$threshold" ]; then
    pass "merged $merged/$total branches ($errors merge errors — within ${MIN_COMPLETION_RATE}% tolerance)"
  else
    fail "only $merged/$total branches merged ($errors errors, $skipped skipped)"
  fi
}

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
summary() {
  printf "\n${C_BOLD}━━━ Summary ━━━${C_RESET}\n"
  printf "  passed : %d\n" "$PASS_COUNT"
  printf "  failed : %d\n" "$FAIL_COUNT"
  printf "  total  : %d\n" "$(( PASS_COUNT + FAIL_COUNT ))"

  if [ "$FAIL_COUNT" -eq 0 ]; then
    printf "\n${C_GREEN}${C_BOLD}All phases complete.${C_RESET}\n\n"
    # Set exit code explicitly before trap fires.
    trap - EXIT
    exit 0
  else
    printf "\n${C_RED}${C_BOLD}%d check(s) failed.${C_RESET}\n\n" "$FAIL_COUNT"
    trap - EXIT
    exit 1
  fi
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────
preflight
setup_project
start_sidecar
phase_plan
phase_run
phase_merge
summary
