# /claw-forge boundaries-audit

Invoke `claw-forge boundaries audit --json` and display a read-only refactor hotspot
report — one row per scored path, sorted by score descending.

## Steps

1. Verify cwd is a claw-forge project:

   ```bash
   test -f claw-forge.yaml || { echo "[claw-forge] No claw-forge.yaml found in cwd. Run this command from the project root."; exit 1; }
   ```

2. Verify the sidecar CLI is on PATH:

   ```bash
   command -v claw-forge >/dev/null 2>&1 || { echo "[claw-forge] sidecar CLI not found. Install: pip install claw-forge"; exit 1; }
   ```

3. Run the audit:

   ```bash
   claw-forge boundaries audit --json
   ```

   If the command exits non-zero, relay the sidecar's error message verbatim and exit 1.

4. Display the output in this format:

   ```
   Boundaries audit — <N> hotspots

   SCORE   PATH                                    PATTERN
     8.4   src/orchestrator/dispatcher.py          split
     7.1   src/agent/runner.py                     extract_collaborators
     6.9   src/state/service.py                    registry
   ```

   - Sort rows by score descending (the sidecar already sorts; preserve that order).
   - Right-align SCORE to one decimal place.
   - If the `hotspots` array is empty, display:
     `No refactor hotspots found. The codebase boundaries look clean.`

5. Exit with code 0.
