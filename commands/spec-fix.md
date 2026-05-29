# /claw-forge spec-fix

Interactively resolve validator errors in an existing `app_spec.xml`. Runs the
claw-forge validator, loads the `claw-forge-spec-authoring` skill to rewrite only
the offending `<feature>` bullets, and loops until the spec is clean or no further
progress is made. The host session displays a per-pass summary of fixed issues.

## Steps

1. Verify cwd is a claw-forge project:
   `test -f claw-forge.yaml` — if absent, display `"Not a claw-forge project (claw-forge.yaml not found)"` and exit 1.

2. Verify the sidecar CLI is on PATH:
   `command -v claw-forge >/dev/null 2>&1` — if not found, display `"claw-forge CLI not found — run: pip install claw-forge"` and exit 1.

3. Resolve the spec file path:
   - If `<spec-file>` was supplied, use it.
   - Otherwise default to `./app_spec.xml`.
   - `test -f <spec-file>` — if absent, display `"Spec file not found: <spec-file>"` and exit 1.

4. Run the validator and capture the result:

   ```
   claw-forge spec validate --json <spec-file>
   ```

   Parse the JSON response:

   - If `"ok": true` (zero errors), display:

     ```
     [claw-forge] spec-fix: <spec-file> is already valid — nothing to fix.
     ```

     and exit 0.

   - If the command exits non-zero for a reason other than validation failures
     (e.g. parse error, file not readable), relay the sidecar error verbatim and exit 1.

5. Display the initial error summary before beginning repairs:

   ```
   [claw-forge] spec-fix: <N> validator error(s) found — starting repair loop.
   ```

   List each error on its own line in the format the sidecar returns (layer, feature
   index or path, message).

6. Load the `claw-forge-spec-authoring` skill with the following context:
   - `mode = fix`
   - `spec_path = <spec-file>`
   - `errors = <parsed error list from step 4>`

   The skill must:
   - Read the current `<spec-file>` from disk.
   - For each error, locate the offending `<feature>` element (or structural element)
     and apply the minimal rewrite needed to satisfy the validator rule.
   - Write the corrected spec back to `<spec-file>`.
   - Leave all error-free elements untouched.

7. After the skill finishes each repair pass, re-run the validator:

   ```
   claw-forge spec validate --json <spec-file>
   ```

   Display a per-pass summary in the format:

   ```
   Pass <N>: fixed <K> error(s), <R> remaining.
   ```

   - If `"ok": true` (zero remaining), display:

     ```
     [claw-forge] spec-fix: spec is now valid.  (<spec-file>)
     ```

     and exit 0.

   - If the remaining error count did not decrease from the previous pass, display:

     ```
     [claw-forge] spec-fix: no progress on pass <N> — manual review required.
     Unresolved errors:
     <list remaining errors>
     ```

     and exit 1.

   - Otherwise, return to step 6 for another repair pass.

## Args

- `<spec-file>` — path to the spec XML file to repair (optional, default: `./app_spec.xml`)
