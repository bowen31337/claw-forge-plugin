# /claw-forge checkpoint

Manually checkpoint all active worktrees via the sidecar git CLI.

## Steps

1. Verify cwd is a claw-forge project:
   `test -f claw-forge.yaml` — if absent, display `"Not a claw-forge project (claw-forge.yaml not found)"` and exit 1.

2. Verify the sidecar CLI is available:
   `claw-forge --version` — if not found on `$PATH`, display `"claw-forge CLI not found — run: pip install claw-forge"` and exit 1.

3. Run the sidecar checkpoint command:
   `claw-forge git checkpoint --json`

4. For each entry in the result, display one row:
   `<slug>  <sha>`

5. If the result is empty, display:
   `no active worktrees`

6. If the command exits non-zero, relay the sidecar's error message verbatim and exit 1.

7. Exit with code 0.
