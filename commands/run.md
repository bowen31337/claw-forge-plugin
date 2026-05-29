# /claw-forge run

Drive the dispatch loop in the host session, executing ready features wave by wave until
the DAG is drained. Loads the `claw-forge-dispatch-loop` skill.

## Usage

```
/claw-forge run                                      — run all ready tasks
/claw-forge run --features <ids>                     — run only the named feature IDs (comma-separated)
/claw-forge run --max-concurrency <N>                — override wave batch size
/claw-forge run --features <ids> --max-concurrency <N>
```

## Steps

1. Verify cwd is a claw-forge project:
   `test -f claw-forge.yaml` — if absent, display `"Not a claw-forge project (claw-forge.yaml not found)"` and exit 1.

2. Verify the sidecar CLI is available:
   `claw-forge --version` — if not found on `$PATH`, display `"claw-forge CLI not found — run: pip install claw-forge"` and exit 1.

3. Verify the state service is running:
   `claw-forge state status --json` — if the command fails or `.running` is `false`, display:
   `"[claw-forge] State service is not running. Start it with: claw-forge state start"`
   and exit 1.

4. Parse arguments:
   - `--features <ids>`: comma-separated feature IDs to filter (optional; default: all tasks)
   - `--max-concurrency <N>`: positive integer wave batch size override (optional; default: read from sidecar)

   If an unrecognised flag is present, display the usage block above and exit 1.
   If `--max-concurrency` is provided but `<N>` is not a positive integer, display:
   `"--max-concurrency must be a positive integer"` and exit 1.

5. Load the `claw-forge-dispatch-loop` skill, passing:
   - **features**: parsed feature ID list (empty list when `--features` is omitted)
   - **max_concurrency**: parsed override value (`null` when `--max-concurrency` is omitted)

   The skill drives the wave loop, prints a per-wave dispatch summary after each wave,
   and exits when the DAG is empty.
