# /claw-forge ui

Opens the Kanban UI in the default browser by invoking `claw-forge ui`.

## Steps

1. Verify cwd is a claw-forge project:
   `test -f claw-forge.yaml` — if absent, display `"Not a claw-forge project (claw-forge.yaml not found)"` and exit 1.

2. Verify the sidecar CLI is available:
   `claw-forge --version` — if not found on `$PATH`, display `"claw-forge CLI not found — run: pip install claw-forge"` and exit 1.

3. Run the UI command:
   `claw-forge ui`

   The sidecar opens the default browser to the Kanban UI and prints the resolved URL to
   stdout, e.g.:

   ```
   http://localhost:8421
   ```

4. Display the resolved URL to the user:

   > UI opened at: `http://localhost:8421`

5. If the command exits non-zero, relay the sidecar's error message verbatim and stop.
   Do not attempt to recover or re-run automatically.
