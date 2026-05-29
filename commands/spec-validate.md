# /claw-forge spec-validate

Run all 4 validator layers against `app_spec.xml` (or a custom spec path) and display
formatted findings. Exits 0 on PASS and 1 on FAIL.

## Usage

```
/claw-forge spec-validate              — validate ./app_spec.xml (default)
/claw-forge spec-validate <path>       — validate spec at <path>
```

## Steps

1. Verify cwd is a claw-forge project:
   `test -f claw-forge.yaml` — if absent, display `"Not a claw-forge project (claw-forge.yaml not found)"` and exit 1.

2. Verify the sidecar CLI is on PATH:
   `command -v claw-forge >/dev/null 2>&1` — if not found, display `"claw-forge CLI not found — run: pip install claw-forge"` and exit 1.

3. Resolve the spec path:
   - If a `<path>` argument was supplied, use it.
   - Otherwise default to `./app_spec.xml`.

   Verify the file exists:
   `test -f <spec_path>` — if absent, display `"[claw-forge] Spec file not found: <spec_path>"` and exit 1.

4. Run the validator:

   ```bash
   claw-forge spec validate --json
   ```

   Pass `--spec <spec_path>` when the path is not the default `./app_spec.xml`.

   The response is a JSON object with the following shape:

   | Field | Type | Description |
   | --- | --- | --- |
   | `status` | `"pass"` \| `"fail"` | Overall validation result |
   | `spec_path` | string | Resolved path to the validated spec file |
   | `layers` | array | One entry per validator layer (see below) |
   | `findings` | array | All findings across every layer; may be empty |

   Each element of `layers`:

   | Field | Type | Description |
   | --- | --- | --- |
   | `name` | string | Layer identifier (`schema`, `semantic`, `shape-annotations`, `overlap`) |
   | `status` | `"pass"` \| `"fail"` | Per-layer result |

   Each element of `findings`:

   | Field | Type | Description |
   | --- | --- | --- |
   | `severity` | `"error"` \| `"warning"` | Finding severity |
   | `layer` | string | Layer that produced this finding |
   | `message` | string | Human-readable description of the issue |
   | `path` | string? | XPath or element reference; omitted when not applicable |
   | `line` | integer? | Source line number; omitted when not applicable |

   If the command exits non-zero before emitting JSON (e.g. the spec file is not valid XML),
   relay the sidecar's error message verbatim and exit 1.

5. Display the validation header:

   ```
   [claw-forge] spec-validate — <spec_path>
   ```

6. Display the per-layer results table:

   ```
   LAYER                        STATUS
   schema                       PASS
   semantic                     PASS
   shape-annotations            PASS
   overlap                      PASS
   ```

   - Print `PASS` when the layer status is `"pass"`, `FAIL` when `"fail"`.
   - Always print all 4 layers in the order returned by the sidecar.

7. If `findings` is non-empty, display each finding:

   ```
   Findings:
     [ERROR]    shape-annotations  Feature #3 missing touches_files for shape="core"
     [WARNING]  semantic           Feature #12 description does not end with observable output
   ```

   - Print `[ERROR]` for `severity: "error"`, `[WARNING]` for `severity: "warning"`.
   - Include `path` after the message when present, formatted as `(at <path>)`.
   - Sort errors before warnings; otherwise preserve sidecar order.

8. Display the summary line:

   On PASS:

   ```
   Result: PASS — all 4 layers passed.
   ```

   On FAIL:

   ```
   Result: FAIL — <N> error(s), <M> warning(s).
   ```

   Where `<N>` is the count of findings with `severity: "error"` and `<M>` is the count
   with `severity: "warning"`.

9. Exit with code 0 when `status` is `"pass"`, exit 1 when `status` is `"fail"`.
