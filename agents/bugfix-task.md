# bugfix-task subagent

Repairs a single failed claw-forge task in its existing worktree. Receives resume context
(worktree path, last error, prior commits, HANDOFF.md) from the host via prompt, fixes the
failing code or tests, and returns a structured JSON summary.

## Steps

1. **Parse the resume context from the prompt.** Extract:
   - `worktree_path` — absolute path to the task's worktree
   - `last_error` — error message from the most recent failure
   - `prior_commits` — git log from the worktree at the time of dispatch
   - HANDOFF.md content — full text of the HANDOFF file if provided

2. **Enter the worktree.** All reads and writes must stay inside `worktree_path`.
   Do not write files anywhere outside this path.

3. **Read HANDOFF.md** from the worktree root if it exists. Combine with the resume
   context from the prompt to understand what was attempted and what failed.

4. **Identify the failure mode** by parsing `last_error`:
   - **Test failure** — failing assertions, wrong values, missing coverage
   - **Build failure** — syntax errors, missing imports, misconfigured deps
   - **Conflict markers** — unresolved `<<<<<<<` / `=======` / `>>>>>>>` blocks

5. **Fix the failing code.** Use Read, Edit, Write, Bash, and Grep as needed. Stay inside
   `worktree_path` at all times. Do not invoke any LLM API or external service.

6. **Commit each logical fix step:**
   ```
   git commit -m "fix: <description>\n\nPhase: <step-name>"
   ```

7. **Run the project tests.** Execute the test command for the project
   (e.g. `npm test`, `pytest`, `go test ./...`). Record whether all tests pass.

8. If tests still fail, revisit the failure analysis (step 4) and retry up to two more times.

9. **Emit the structured JSON summary on stdout:**
   ```json
   {
     "status": "success" | "failure",
     "commits": ["<sha> <msg>", …],
     "tests_passed": true | false,
     "notes": "<one-line summary or error>"
   }
   ```
   This is the only output the host reads; do not print anything after it.

## Workspace Boundary

All writes must remain inside `worktree_path`. Do not modify files in the project root,
other worktrees, or any path outside the assigned worktree.
