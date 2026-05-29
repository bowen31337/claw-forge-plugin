# /claw-forge merge

Enumerate ready feature branches via `claw-forge state ready` and squash-merge each to
the target branch. Routes merge conflicts into the claw-forge-conflict-recovery skill.

## Steps

1. Verify cwd is a claw-forge project:

   ```bash
   test -f claw-forge.yaml || { echo "[claw-forge] No claw-forge.yaml found in cwd. Run this command from the project root."; exit 1; }
   ```

2. Verify the sidecar CLI is on PATH:

   ```bash
   command -v claw-forge >/dev/null 2>&1 || { echo "[claw-forge] sidecar CLI not found. Install: pip install claw-forge"; exit 1; }
   ```

3. Verify the sidecar state service is responsive:

   ```bash
   claw-forge state status --json
   ```

   If the response contains `"running": false` or the command exits non-zero, display:

   ```
   [claw-forge] State service is not running. Start it with: claw-forge state start
   ```

   and exit 1.

4. Query all ready branches:

   ```bash
   claw-forge state ready --json
   ```

   The response is a JSON array. Each element has at minimum:

   | Field | Type | Description |
   | --- | --- | --- |
   | `id` | string | Task identifier |
   | `slug` | string | Feature branch slug (e.g. `feat/auth-login`) |

   If the array is empty, display:

   ```
   No ready branches to merge.
   ```

   and exit 0.

5. For each ready branch in the array, squash-merge it to the target branch:

   a. Display: `Merging <slug>...`

   b. Run: `claw-forge git squash-merge <slug> --json`

   c. If the response contains `"status": "merged"`, record the slug as **merged**.

   d. If the response contains `"status": "conflict"` or the command exits non-zero with
      a `merge_failed` envelope, record the slug as **conflict** and load the
      `claw-forge-conflict-recovery` skill, passing the full sidecar JSON envelope as
      context. After the skill returns:
      - If the skill verdict is `"resolved"`, record the slug as **merged**.
      - If the skill verdict is `"unresolvable"`, record the slug as **failed** and
        PATCH the task to failed:
        `claw-forge state patch <id> --status failed --error "unresolvable merge conflict" --json`

6. Display a per-branch status table:

   ```
   SLUG                  RESULT
   feat/auth-login       merged
   feat/ui-dashboard     merged
   feat/db-schema        failed  (unresolvable conflict)
   ```

7. Display a one-line summary:

   ```
   Merge complete: <merged_count> merged, <failed_count> failed.
   ```

8. If any branch failed, exit 1. Otherwise exit 0.
