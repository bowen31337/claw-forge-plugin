# /claw-forge stash-list

Display claw-forge stash entries including auto-stashed leak snapshots created by the
dispatch loop's post-Task leak-check phase.

## Steps

1. Verify cwd is a claw-forge project (`test -f claw-forge.yaml`).
2. Fetch all stash entries from the sidecar:
   `claw-forge git stash list --json`
   Response is a JSON array; each element has at minimum `ref`, `timestamp`, and
   `task_id` (nullable).
3. If the array is empty, display:
   ```
   No claw-forge stash entries.
   ```
4. Otherwise display one row per entry, most recent first (`stash@{0}` first):
   ```
   REF          TIMESTAMP             TASK
   stash@{0}    2026-05-29 14:23:01   task-42
   stash@{1}    2026-05-28 09:15:44   task-38
   stash@{2}    2026-05-27 22:04:12   (manual)
   ```
   - `TASK` shows `task_id` when present; `(manual)` when `task_id` is null.
