---
name: claw-forge-feature-implementation
description: Per-feature subagent workflow — implement, test, checkpoint, and return a structured JSON summary
triggers:
  - claw-forge-feature-implementation
  - coding-feature
---

## Overview

This skill describes what the `coding-feature` subagent must do when implementing a
single feature inside an assigned claw-forge worktree. It enforces the workspace
boundary (all writes stay inside the worktree), runs project tests, and emits a
structured JSON summary on stdout so the dispatch loop can PATCH the task record.

## Steps

1. **Enter the worktree.** `cd` into the assigned worktree path before touching any
   files. This is the workspace boundary — do not write files anywhere else.

2. **Read the task context.** Review the task description, acceptance criteria, and
   the list of files the task is claimed to touch (`touches_files`).

3. **Implement the feature.** Use Read, Write, Edit, Bash, and Grep as needed. Stay
   inside the worktree at all times. Do not invoke `claude_agent_sdk` or any LLM API.

4. **Commit checkpoints.** After each logical sub-step, commit with a `Phase:` trailer:
   ```
   git commit -m "implement X\n\nPhase: <step-name>"
   ```

5. **Run tests.** Execute the project's test command (e.g. `npm test`, `pytest`, `go test ./...`).
   Record whether tests pass.

6. **Emit the structured JSON summary on stdout:**
   ```json
   {
     "status": "success" | "failure",
     "commits": ["<sha> <msg>", …],
     "tests_passed": true | false,
     "notes": "<one-line summary or error>"
   }
   ```
   This is the only output the dispatch loop reads; do not print anything after it.

## Workspace Boundary

The workspace boundary is critical. The dispatch loop runs `claw-forge git leak-check`
after every subagent invocation and auto-stashes writes outside the worktree. Staying
inside the assigned worktree path keeps the project root clean and prevents cross-task
interference.
