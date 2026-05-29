#!/usr/bin/env sh
# SessionStart hook — bootstraps the claw-forge sidecar.
# Exits 0 in every code path; never aborts the host session.

MIN_SIDECAR="0.6.0"

# 1. Silently exit in non-claw-forge directories.
if [ ! -f "./claw-forge.yaml" ] && [ ! -d "./.claw-forge" ]; then
  exit 0
fi

# 2. Check sidecar CLI is on PATH.
if ! command -v claw-forge >/dev/null 2>&1; then
  echo "[claw-forge plugin] sidecar CLI not found. Install: pip install claw-forge"
  exit 0
fi

# 3. Version gate.
CURRENT="$(claw-forge --version 2>/dev/null | awk '{print $NF}')"
SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")}"
if ! "$SCRIPT_DIR/version-gte.sh" "$CURRENT" "$MIN_SIDECAR" 2>/dev/null; then
  echo "[claw-forge plugin] sidecar $CURRENT is older than required $MIN_SIDECAR."
  echo "                   Upgrade: pip install -U 'claw-forge>=$MIN_SIDECAR'"
  exit 0
fi

# 4. Start state service if not already running.
STATUS="$(claw-forge state status --json 2>/dev/null || echo '{}')"
RUNNING="$(printf '%s' "$STATUS" | jq -r '.running // false' 2>/dev/null || echo 'false')"
if [ "$RUNNING" != "true" ]; then
  if ! claw-forge state start --detach >/dev/null 2>&1; then
    echo "[claw-forge plugin] failed to start state service. Try: claw-forge state start"
    exit 0
  fi
fi

# 5. Print ready banner.
STATUS="$(claw-forge state status --json 2>/dev/null || echo '{}')"
PORT="$(printf '%s' "$STATUS" | jq -r '.port // empty' 2>/dev/null)"
UI_PORT="$(printf '%s' "$STATUS" | jq -r '.ui_port // empty' 2>/dev/null)"
SESSION="$(printf '%s' "$STATUS" | jq -r '.session_id // "(no session yet)"' 2>/dev/null)"
echo "[claw-forge] sidecar ready  state=:${PORT:-?} ui=:${UI_PORT:-—} session=$SESSION"
