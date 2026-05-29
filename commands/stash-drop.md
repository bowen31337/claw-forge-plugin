# /claw-forge stash-drop

Drop a claw-forge stash entry by reference.

## Steps

1. If `<ref>` was not supplied, display usage and stop:
   `Usage: /claw-forge stash-drop <ref>  (e.g. claw-forge-leak-<task-id>-<ts>)`

2. Verify cwd is a claw-forge project (`test -f claw-forge.yaml`).

3. Verify the sidecar state service is responsive:
   `claw-forge state status --json`
   On failure, display the error and stop.

4. Drop the stash entry:
   `claw-forge git stash drop <ref> --json`
   On error (entry not found or sidecar failure), display the sidecar error message
   and stop.

5. Query the remaining stash count:
   `claw-forge git stash list --json | jq 'length'`

6. Display confirmation and the new stash count:

   ```
   Dropped stash entry <ref>
   Stash entries remaining: <count>
   ```

7. Exit with code 0.

## Args

- `<ref>` — stash reference to drop (e.g. `claw-forge-leak-<task-id>-<ts>` or `stash@{0}`)
