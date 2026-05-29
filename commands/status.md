# /claw-forge status

Display a textual session overview for the current claw-forge project.

## Steps

1. Verify cwd is a claw-forge project (`test -f claw-forge.yaml`).

2. Call the state service:
   `claw-forge state status --json`
   If the command fails or returns non-zero, display:
   `[claw-forge] State service is not running. Start it with: claw-forge state`
   and stop.

3. Parse the JSON response and extract:
   - `.running` — sidecar state (`true`/`false`)
   - `.port` — state service port
   - `.session_id` — current session identifier
   - `.active_tasks` — count of in-progress tasks

4. Display the session overview:

   ```
   claw-forge status
   ─────────────────────────────────
   Sidecar state:  running
   Port:           8420
   Session ID:     <session_id>
   Active tasks:   <active_tasks>
   ```

   Replace `running` with `stopped` when `.running` is `false`.

5. Exit with code 0.
