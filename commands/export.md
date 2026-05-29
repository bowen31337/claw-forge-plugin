# /claw-forge export <format>

Export session and training data for the current claw-forge project. The sidecar writes
the export to a file in `.claw-forge/exports/` and prints the output file path on success.

## Supported formats

- `jsonl` — newline-delimited JSON; one record per completed task (default for ML pipelines)
- `json` — single JSON array of all task records
- `csv` — comma-separated; useful for spreadsheet analysis
- `markdown` — human-readable session summary with feature status table

## Steps

1. Verify cwd is a claw-forge project:

   ```bash
   test -f claw-forge.yaml || { echo "[claw-forge] No claw-forge.yaml found in cwd. Run this command from the project root."; exit 1; }
   ```

2. Verify the sidecar CLI is on PATH:

   ```bash
   command -v claw-forge >/dev/null 2>&1 || { echo "[claw-forge] sidecar CLI not found. Install: pip install claw-forge"; exit 1; }
   ```

3. Check that `<format>` was provided. If it is missing, print the supported formats and
   stop — do not guess a default.

4. Run the export:

   ```bash
   claw-forge export <format>
   ```

   The sidecar writes the file and prints the absolute path to stdout, e.g.:

   ```
   /path/to/project/.claw-forge/exports/session-2026-05-29T14-32-00.jsonl
   ```

5. Display the output file path to the user so they can open or copy it:

   > Export written to: `/path/to/project/.claw-forge/exports/session-2026-05-29T14-32-00.jsonl`

6. If the command exits non-zero, relay the sidecar's error message verbatim and stop.
   Do not attempt to recover or re-run automatically.

## Notes

- Training-trace capture from the host session's internal subagent stream is not available
  in plugin v0.1 (see PRD §5 non-goals). The export covers state-service records: task
  metadata, status, commit hashes, error messages, and timing. Subagent message-level traces
  are deferred to v0.2.
- The state service must be running for the export to include live session data. If the
  service is offline, the sidecar exports from the last persisted snapshot in
  `.claw-forge/state.db`.
