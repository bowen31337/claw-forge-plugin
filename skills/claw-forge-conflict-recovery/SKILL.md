---
name: claw-forge-conflict-recovery
description: Inspect and resolve git conflict markers, re-run tests, and return a structured resolution verdict
triggers:
  - claw-forge-conflict-recovery
  - sync_conflict
  - merge_failed
---

## Overview

This skill replaces the removed `git/conflict_advisor.py` module from sidecar v0.5.x.
It is loaded by the dispatch loop when `claw-forge git squash-merge` reports a conflict,
or by `/claw-forge merge` when a ready branch cannot be merged cleanly. The skill
inspects the conflict markers, resolves them, re-runs tests, and returns a structured
resolution verdict.

## Steps

1. **Identify the conflict.** Read the sidecar JSON envelope for the failing merge to
   determine which worktree and branch are involved:
   - `sync_conflict`: conflict arose during `claw-forge git sync-worktree`
   - `merge_failed`: conflict arose during `claw-forge git squash-merge`

2. **List conflict markers.** Inside the worktree:
   ```sh
   git diff --name-only --diff-filter=U
   ```
   Each file with `<<<<<<<` markers needs manual resolution.

3. **Resolve each conflicted file.** For each file:
   a. Read the full file including `<<<<<<<`, `=======`, and `>>>>>>>` markers.
   b. Understand the intent of both sides (incoming vs. current).
   c. Write the resolved version using Edit; remove all conflict markers.

4. **Stage resolved files:**
   ```sh
   git add <resolved-file> …
   ```

5. **Complete the merge:**
   - For `sync_conflict` (during rebase/merge from target):
     `git rebase --continue` or `git merge --continue`
   - For `merge_failed` (during squash-merge to target):
     `git commit --no-edit`

6. **Re-run tests.** Execute the project's test command. A conflict resolution that
   breaks tests is not a valid resolution — fix the code until tests pass.

7. **Report the resolution verdict:**
   ```json
   {
     "status": "resolved" | "unresolvable",
     "files_resolved": ["<path>", …],
     "tests_passed": true | false,
     "notes": "<one-line summary>"
   }
   ```

## When Unresolvable

If the conflict cannot be resolved without domain knowledge beyond the diff context,
set `status = "unresolvable"` and return. The dispatch loop will PATCH the task →
`failed` with the conflict details so the user can run `/claw-forge fix <task-id>`.
