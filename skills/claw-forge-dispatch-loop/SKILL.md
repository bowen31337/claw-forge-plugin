---
name: claw-forge-dispatch-loop
description: Wave-by-wave Task-tool dispatch pattern for the claw-forge orchestration loop
triggers:
  - claw-forge-dispatch-loop
  - /claw-forge run
  - /claw-forge resume
---

## Overview

This skill drives the main dispatch loop for claw-forge feature execution. It queries
the sidecar state service for ready tasks, provisions worktrees, emits parallel Task
tool calls (one per ready task), collects results, and loops until the DAG is fully
drained. All agent invocations bill against the host session's Pro/Max pool — no
`claude_agent_sdk` imports anywhere.

## Parameters

Callers (e.g. `/claw-forge run`) may pass these optional parameters:

- **features** — list of feature IDs to restrict execution to (empty = all tasks)
- **max_concurrency** — integer wave batch size override (`null` = read from sidecar)

## Steps

1. Determine `MAX_BATCH`:
   - If `max_concurrency` parameter is non-null, use it directly.
   - Otherwise: `claw-forge state status --json | jq -r '.max_concurrency'`

2. **Query the next wave:**

   ```bash
   claw-forge state ready --json --limit $MAX_BATCH [--features <ids>]
   ```

   Include `--features <ids>` only when the `features` parameter is non-empty.
   If the batch is empty, print the final dispatch summary (see Display) and exit with code 0.

3. **Pre-dispatch** (for each task in the batch):
   a. Claim files:
      `claw-forge file-claim ${task.id} --files ${task.touches_files} --json`
      On claim conflict: defer the task to the next wave and skip steps b–d.
   b. Create worktree:
      `claw-forge git create-worktree ${task.slug} --json`
   c. Sync worktree:
      `claw-forge git sync-worktree ${task.slug} --json`
      On `sync_conflict`: PATCH task → `failed`, release claim, skip step d.
   d. Snapshot baseline for leak detection:
      `claw-forge git leak-snapshot ${task.id} --json`

4. **Dispatch** — emit all pre-dispatched tasks as parallel Task calls in a **single
   assistant response**:

   ```
   Task(subagent_type="coding-feature", prompt=render(task1))
   Task(subagent_type="coding-feature", prompt=render(task2))
   …
   ```

5. **Collect** — for each (task, result) pair after all subagents return:
   a. Leak check: `claw-forge git leak-check ${task.id} --json`
      (auto-stashes any writes outside the worktree)
   b. On success:
      - PATCH status → `completed`:
        `claw-forge state patch ${task.id} --status completed --json`
      - squash-merge: `claw-forge git squash-merge ${task.slug} --json`
        On merge conflict: load the `claw-forge-conflict-recovery` skill.
   c. On failure:
      - PATCH status → `failed`:
        `claw-forge state patch ${task.id} --status failed --error '${result.error}' --json`
   d. Release file claim: `claw-forge file-release ${task.id}`

6. **Display wave summary** — after all tasks in the wave are collected, print one line:

   ```
   Wave <N>  dispatched=<d>  completed=<c>  failed=<f>  deferred=<r>
   ```

7. Return to step 2.

## Display

After the final wave (step 2 returns an empty batch), print a separator and totals:

```
────────────────────────────────────────────────────────
Total  dispatched=<D>  completed=<C>  failed=<F>
```

Then exit with code 0.

## Concurrency

`MAX_BATCH` defaults to `agent.max_concurrency` from `claw-forge.yaml` (overridable via
the `max_concurrency` parameter). All tasks in a wave are dispatched in a **single
assistant response** as parallel Task calls; the host waits until every subagent returns
before processing results.

The sidecar's shape-aware scheduler ensures at most one `shape="core"` task runs per
wave — `claw-forge state ready` enforces this transparently.
