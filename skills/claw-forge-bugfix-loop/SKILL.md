---
name: claw-forge-bugfix-loop
description: Interactive bugfix workflow with resume context — fetch task record, hydrate HANDOFF.md, dispatch bugfix-task subagent
triggers:
  - claw-forge-bugfix-loop
  - /claw-forge fix
---

## Overview

This skill is loaded by `/claw-forge fix <task-id>` to repair a single failed task.
It fetches the task record and resume context from the sidecar, hydrates `HANDOFF.md`
in the existing worktree, dispatches the `bugfix-task` subagent, and PATCHes the task
status on completion. The skill displays the final fix verdict.

## Steps

1. **Fetch the task record:**
   `claw-forge state get ${task_id} --json`
   Extract: `status`, `last_error`, `worktree_path`, `slug`, `touches_files`.

2. **Gather resume context.**
   - List prior commits in the worktree:
     `git -C ${worktree_path} log --oneline --format='%H %s' | head -20`
   - Read `HANDOFF.md` from the worktree root if it exists; create it if absent.
   - Capture the last test output from the task record's `last_error` field.

3. **Write `HANDOFF.md`** (or append to existing) in the worktree:
   ```markdown
   ## Resume context

   **Last error:** <last_error>

   **Prior commits:**
   <list>

   **Notes:** <any additional context>
   ```

4. **Dispatch the `bugfix-task` subagent:**
   ```
   Task(
     subagent_type="bugfix-task",
     prompt=<structured resume context including HANDOFF.md contents, last error, and worktree path>
   )
   ```

5. **Collect the subagent result.** The `bugfix-task` subagent returns a structured
   summary `{status, commits, tests_passed, notes}`.

6. **PATCH the task status:**
   - On success: `claw-forge state patch ${task_id} --status completed --json`
   - On failure: `claw-forge state patch ${task_id} --status failed --error '${notes}' --json`

7. **Display the fix verdict** including updated task status, commit SHAs, and whether
   the branch is now ready for `/claw-forge merge`.
