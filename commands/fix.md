# /claw-forge fix

Enter the claw-forge bugfix loop for a single failed task. Fetches the task record and
resume context (HANDOFF.md, prior commits, last error), dispatches the `bugfix-task`
subagent, and displays the fix verdict with updated task status on completion.

## Steps

1. If `<task-id>` was not supplied, display usage and stop:

   ```
   Usage: /claw-forge fix <task-id>
   ```

2. Verify cwd is a claw-forge project:
   `test -f claw-forge.yaml` — if absent, display `"Not a claw-forge project (claw-forge.yaml not found)"` and exit 1.

3. Verify the sidecar CLI is on PATH:
   `command -v claw-forge >/dev/null 2>&1` — if not found, display `"claw-forge CLI not found — run: pip install claw-forge"` and exit 1.

4. Verify the sidecar state service is running:
   `claw-forge state status --json`
   If the response contains `"running": false` or the command exits non-zero, display:
   `"[claw-forge] State service is not running. Start it with: claw-forge state start"`
   and exit 1.

5. Fetch the task record to confirm the task exists:
   `claw-forge state get <task-id> --json`
   On non-zero exit or missing record, relay the sidecar error verbatim and exit 1.

6. Load the `claw-forge-bugfix-loop` skill, passing `task_id = <task-id>`.
   The skill gathers resume context, hydrates `HANDOFF.md` in the worktree, dispatches
   the `bugfix-task` subagent, PATCHes the task status, and displays the fix verdict.

## Args

- `<task-id>` — identifier of the failed task to repair (required)
