# /claw-forge spec-import

Scan the existing project structure and produce a `brownfield_manifest.json` (catalog of
current codebase state) and an `additions_spec.xml` (spec for new features to layer on
top). Loads the `claw-forge-spec-authoring` skill in brownfield mode and displays both
output paths on success.

## Steps

1. Verify the claw-forge CLI is available:
   `command -v claw-forge >/dev/null 2>&1` — if not found, display
   `"claw-forge CLI not found — run: pip install claw-forge"` and exit 1.

2. Load the `claw-forge-spec-authoring` skill, passing:
   - **mode**: `brownfield`
   - **output_manifest**: `./brownfield_manifest.json`
   - **output_spec**: `./additions_spec.xml`

   The skill scans the existing codebase, writes `brownfield_manifest.json`, drafts
   `additions_spec.xml`, runs validation, and displays both output paths on completion:

   ```
   brownfield_manifest.json written → ./brownfield_manifest.json
   additions_spec.xml written → ./additions_spec.xml  (N features: M core, K plugin)
   ```
