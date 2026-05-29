# /claw-forge worktrees-prune

Cleans up orphaned worktrees under `.claw-forge/worktrees/` via the sidecar cleanup CLI.

## Steps

1. Verify cwd is a claw-forge project:
   `test -f claw-forge.yaml` — if absent, display `"Not a claw-forge project (claw-forge.yaml not found)"` and exit 1.

2. Verify the sidecar CLI is available:
   `claw-forge --version` — if not found on `$PATH`, display `"claw-forge CLI not found — run: pip install claw-forge"` and exit 1.

3. Run the sidecar cleanup command:
   `claw-forge git cleanup --json`

4. Parse the JSON response and display the pruned worktree count:
   `Pruned <n> orphaned worktree(s).`

5. Exit with code 0.
