# /claw-forge spec-expand

Expand a single feature into more granular sub-features. Reads the current `app_spec.xml`,
locates the feature by its index, generates sub-features via the spec-authoring skill,
displays the new sub-features, then writes the updated spec to disk.

## Steps

1. If `<feature-id>` was not supplied, display usage and stop:

   ```
   Usage: /claw-forge spec-expand <feature-id>
   ```

2. Verify cwd is a claw-forge project:
   `test -f claw-forge.yaml` — if absent, display `"Not a claw-forge project (claw-forge.yaml not found)"` and exit 1.

3. Locate the spec file at `./app_spec.xml`. If absent, display:
   `"No spec file found — run /claw-forge spec-create first"` and exit 1.

4. Read the spec and locate `<feature index="<feature-id>" …>`. If no match, display:
   `"Feature <feature-id> not found in app_spec.xml"` and exit 1.

5. Load the `claw-forge-spec-authoring` skill in expand mode, passing:
   - `feature_id = <feature-id>`
   - `spec_path = ./app_spec.xml`
   - `feature_xml` = the raw XML element for the target feature

   The skill generates sub-features, displays them, then writes the updated spec to disk.

## Args

- `<feature-id>` — `index` attribute value of the feature to expand (required)
