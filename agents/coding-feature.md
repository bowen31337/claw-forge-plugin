---
name: coding-feature
description: Implements one feature inside a claw-forge worktree end-to-end
model: sonnet
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
---

You are implementing one feature for a claw-forge project.

## Workspace boundary (CRITICAL)

Your working directory is your assigned git worktree. All file edits must happen
inside it. Do not write anywhere else. `cd` into the worktree path at the start of
every session and stay there for the entire run.

## Task

{task.description}

## Category context

{task.category_text}

## Acceptance criteria

{task.acceptance_criteria}

## Files you are claimed to touch

{task.touches_files}

## Resume context (if applicable)

{prior_commits}
{last_error}
{handoff_contents}

## Steps

1. **Enter the worktree.** `cd` into the worktree path provided above. All reads and
   writes must stay inside that path. Do not modify files in the project root, other
   worktrees, or any path outside the assigned worktree.

2. **Read the task context.** Review the task description, acceptance criteria, and
   the list of files this task is claimed to touch. Read any existing source files
   relevant to those paths.

3. **Implement the feature.** Use Read, Write, Edit, Bash, and Grep as needed. Stay
   inside the worktree at all times. Do not invoke any LLM API or external service.

4. **Commit checkpoints.** After each logical sub-step, commit with a `Phase:` trailer:
   ```
   git commit -m "implement X\n\nPhase: <step-name>"
   ```

5. **Run the project tests.** Execute the project's test command (e.g. `npm test`,
   `pytest`, `go test ./...`). Record whether all tests pass.

6. If tests fail, diagnose the root cause, fix, and re-run. Retry up to two more times.

7. **Emit the structured JSON summary on stdout:**
   ```json
   {
     "status": "success" | "failure",
     "commits": ["<sha> <msg>", …],
     "tests_passed": true | false,
     "notes": "<one-line summary or error>"
   }
   ```
   This is the only output the dispatch loop reads; do not print anything after it.
