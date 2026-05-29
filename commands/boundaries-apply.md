# /claw-forge boundaries-apply

Refactor one hotspot by path or all hotspots serially in auto mode by applying a
canonical boundary pattern. Loads the `claw-forge-boundaries-refactor` skill and
displays a per-refactor verdict after each apply.

## Usage

```
/claw-forge boundaries-apply <path>   — refactor a single hotspot at <path>
/claw-forge boundaries-apply --auto   — refactor all hotspots, descending score order
```

## Steps

1. Verify cwd is a claw-forge project:
   `test -f claw-forge.yaml` — if absent, display `"Not a claw-forge project (claw-forge.yaml not found)"` and exit 1.

2. Verify the sidecar CLI is available:
   `claw-forge --version` — if not found on `$PATH`, display `"claw-forge CLI not found — run: pip install claw-forge"` and exit 1.

3. Check that exactly one of `<path>` or `--auto` was provided. If neither is present,
   display usage and stop:

   ```
   Usage: /claw-forge boundaries-apply <path>
          /claw-forge boundaries-apply --auto
   ```

4. Fetch the boundaries audit report to confirm hotspot data is available:

   ```bash
   claw-forge boundaries audit --json
   ```

   On non-zero exit, relay the sidecar error message verbatim and stop.

   - In **single** mode (`<path>` supplied): confirm that `<path>` appears in the audit
     report. If it does not, display `"No hotspot found for <path>"` and stop.
   - In **auto** mode (`--auto`): confirm that the report contains at least one hotspot.
     If the report is empty, display `"No hotspots found in audit report"` and stop.

5. Load the `claw-forge-boundaries-refactor` skill, passing:
   - **mode**: `single` or `auto`
   - **path**: `<path>` (single mode only)
   - **audit_report**: the JSON output from step 4

   The skill applies the canonical refactor pattern for each targeted hotspot and
   displays a per-refactor verdict (`path`, `pattern`, `status`, `tests_passed`,
   `notes`) after each apply. In auto mode the skill stops on the first `failed`
   verdict and marks remaining hotspots `skipped`.
