# /claw-forge plan

Parse `app_spec.xml` (or a custom spec path) and seed the DAG into the state DB.

## Usage

```
/claw-forge plan              — parse ./app_spec.xml (default)
/claw-forge plan <path>       — parse spec at <path>
```

## Steps

1. Verify cwd is a claw-forge project:

   ```bash
   test -f claw-forge.yaml || { echo "[claw-forge] No claw-forge.yaml found in cwd. Run this command from the project root."; exit 1; }
   ```

2. Verify the sidecar CLI is on PATH:

   ```bash
   command -v claw-forge >/dev/null 2>&1 || { echo "[claw-forge] sidecar CLI not found. Install: pip install claw-forge"; exit 1; }
   ```

3. Resolve the spec path:
   - If a `<path>` argument was supplied, use it.
   - Otherwise default to `./app_spec.xml`.

   Verify the file exists:
   ```bash
   test -f <spec_path> || { echo "[claw-forge] Spec file not found: <spec_path>"; exit 1; }
   ```

4. Parse the spec and seed the DAG:

   ```bash
   claw-forge plan --spec <spec_path> --json
   ```

   The response is a JSON object with at minimum:

   | Field | Type | Description |
   |---|---|---|
   | `features_created` | integer | Number of features seeded into the DAG |
   | `categories` | array | Each element has `name` (string) and `count` (integer) |
   | `warnings` | array | Parser warnings as strings; may be empty |

   If the command exits non-zero, relay the sidecar's error message verbatim and exit 1.

5. Display the plan summary:

   ```
   [claw-forge] Plan seeded — <features_created> feature(s) queued.

   CATEGORY                   FEATURES
   <category.name>            <category.count>
   <category.name>            <category.count>
   ...
   ```

   - One row per entry in `categories`, in the order returned by the sidecar.
   - If `categories` is empty, omit the table and display only the first line.

6. If `warnings` is non-empty, display each warning:

   ```
   Warnings:
     • <warning>
     • <warning>
   ```

7. Exit with code 0.
