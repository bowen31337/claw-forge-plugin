# /claw-forge worktrees-list

Displays all active worktrees under `.claw-forge/worktrees/`.

## Steps

1. Verify cwd is a claw-forge project (`test -f claw-forge.yaml`).
2. Fetch the worktree list from the sidecar:
   `claw-forge git list --json`
3. For each entry in the result, display one row:
   `<branch>  <sha>`
4. If the result is empty, display:
   `no active worktrees`
