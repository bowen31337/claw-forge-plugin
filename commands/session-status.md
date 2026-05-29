# /claw-forge session-status

Display the live state of the current claw-forge session — one row per task with its
current status and the timestamp of its most recent state-service event.

This command replaces `/claw-forge pool-status`. The provider pool no longer exists;
per-task execution state is now the relevant live signal.

## Steps

1. Verify cwd is a claw-forge project:

   ```bash
   test -f claw-forge.yaml || { echo "[claw-forge] No claw-forge.yaml found in cwd. Run this command from the project root."; exit 1; }
   ```

2. Verify the sidecar CLI is on PATH:

   ```bash
   command -v claw-forge >/dev/null 2>&1 || { echo "[claw-forge] sidecar CLI not found. Install: pip install claw-forge"; exit 1; }
   ```

3. Fetch session-level metadata:

   ```bash
   claw-forge state status --json
   ```

   If the response contains `"running": false` (or the command exits non-zero), display:

   ```
   [claw-forge] State service is not running. Start it with: claw-forge state start
   ```

   and exit 1.

4. Fetch all tasks for the current session:

   ```bash
   claw-forge state list --json
   ```

   The response is a JSON object with a `tasks` array. Each element has at minimum:

   | Field | Type | Description |
   |---|---|---|
   | `id` | string | Task identifier |
   | `slug` | string | Human-readable slug (e.g. `feat/auth-login`) |
   | `status` | string | `pending` \| `running` \| `completed` \| `failed` \| `skipped` |
   | `last_event` | string \| null | Name of the most recent state-service event (e.g. `task_dispatched`, `squash_merged`, `task_failed`) |
   | `last_event_at` | string \| null | ISO-8601 timestamp of `last_event`, or `null` if no events yet |

5. Display the output in this format:

   ```
   Session: <session_id>   service: :<port>   tasks: <total>

   SLUG                  STATUS      LAST EVENT           LAST EVENT AT
   feat/auth-login       completed   squash_merged        2026-05-29 14:32:01
   feat/ui-dashboard     running     task_dispatched      2026-05-29 14:35:44
   feat/db-schema        pending     —                    —
   feat/api-routes       failed      task_failed          2026-05-29 14:33:12
   ```

   - Sort rows: `running` first, then `pending`, then `failed`, then `completed`, then `skipped`.
   - For `null` timestamps or events, display `—`.
   - If `tasks` is empty, display `No tasks found. Run /claw-forge plan to seed the DAG.`

6. If `claw-forge state list` exits non-zero, relay the sidecar's error message verbatim
   and exit 1. Do not attempt to recover or re-run automatically.
