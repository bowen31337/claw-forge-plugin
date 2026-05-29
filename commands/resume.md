# /claw-forge resume

Resume paused tasks for the current claw-forge session and re-enter the dispatch loop.

## Steps

1. Verify cwd is a claw-forge project:

   ```bash
   test -f claw-forge.yaml || { echo "[claw-forge] No claw-forge.yaml found in cwd. Run this command from the project root."; exit 1; }
   ```

2. Verify the sidecar CLI is on PATH:

   ```bash
   command -v claw-forge >/dev/null 2>&1 || { echo "[claw-forge] sidecar CLI not found. Install: pip install claw-forge"; exit 1; }
   ```

3. Resume paused tasks:

   ```bash
   claw-forge state resume --json
   ```

   The response is a JSON object with at minimum:

   | Field | Type | Description |
   |---|---|---|
   | `resumed` | integer | Number of tasks transitioned out of `paused` state |
   | `session_id` | string | Current session identifier |

   If the command exits non-zero, relay the sidecar's error message verbatim and exit 1.

4. Display the resume summary:

   ```
   [claw-forge] Resumed <resumed> task(s) — re-entering dispatch loop.
   ```

   If `resumed` is 0, display instead:

   ```
   [claw-forge] No paused tasks found. Nothing to resume.
   ```

   and exit 0 without entering the dispatch loop.

5. Load the `claw-forge-dispatch-loop` skill and run the dispatch loop to completion.
