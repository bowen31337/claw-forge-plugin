# /claw-forge spec-create

Interactively generate an `app_spec.xml` from a project description. Prompts for project
details, drafts and annotates features with shape classifications, validates the result
via the sidecar, and writes the spec to disk. Displays the output path and feature-count
summary on success.

## Usage

```
/claw-forge spec-create              — write spec to ./app_spec.xml (default)
/claw-forge spec-create <path>       — write spec to <path>
```

## Steps

1. Verify the sidecar CLI is on PATH:
   `command -v claw-forge >/dev/null 2>&1` — if not found, display
   `"claw-forge CLI not found — run: pip install claw-forge"` and exit 1.

2. Resolve the output path:
   - If a `<path>` argument was supplied, use it.
   - Otherwise default to `./app_spec.xml`.

   If a file already exists at the resolved path, display:
   `"[claw-forge] <path> already exists — pass a different path or delete the file first."`
   and exit 1.

3. Load the `claw-forge-spec-authoring` skill, passing:
   - **output_path**: resolved output path from step 2
   - **mode**: `greenfield`

   The skill gathers project context interactively, drafts features with shape
   annotations, validates the spec via `claw-forge spec validate --json`, writes
   the file, and displays:

   ```
   app_spec.xml written → <output_path>  (N features: M core, K plugin)
   ```

## Args

- `<path>` — destination path for the generated spec (optional; default: `./app_spec.xml`)
