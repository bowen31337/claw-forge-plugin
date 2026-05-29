# Sidecar contract

**Applies to:** plugin v0.1.0 + sidecar [`claw-forge`](https://github.com/<org>/claw-forge) v0.6.0+

This document lists every `claw-forge` CLI subcommand the plugin calls, the flags it
passes, and the JSON envelope each subcommand emits on stdout when `--json` is given.
It is the stability boundary between the plugin (markdown + shell) and the sidecar
(Python package). Breaking changes to any of these commands require a coordinated
plugin release.

---

## Conventions

- Every command that supports `--json` writes a single JSON object to stdout on
  success, or `{"ok": false, "error": "<message>"}` on failure, and exits non-zero.
- Commands without `--json` write human-readable text only; the plugin does not parse
  their output.
- All state mutations go through the sidecar CLI — the plugin never reads or writes
  `.claw-forge/state.db` directly.

---

## Version probe

### `claw-forge --version`

Returns the installed sidecar version string to stdout (plain text, no `--json`).
Used by `hooks/ensure-sidecar.sh` to enforce `>= 0.6.0`.

```
0.6.0
```

---

## State service

### `claw-forge state status --json`

Returns sidecar service state for the current project directory.

```json
{
  "ok": true,
  "running": true,
  "port": 8420,
  "ui_port": 8421,
  "project_root": "/path/to/project",
  "session_id": "sess_abc123"
}
```

| Field | Type | Notes |
| --- | --- | --- |
| `running` | bool | `false` when the service is not up |
| `port` | int | State service HTTP port (default 8420) |
| `ui_port` | int | Kanban UI port (default 8421) |
| `project_root` | string | Absolute path of the detected project root |
| `session_id` | string | Current session identifier |

### `claw-forge state start --detach`

Starts the state service in the background. No `--json` flag; exits 0 when the
service is up or was already running. Human-readable status line on stdout.

### `claw-forge state stop-all --json`

Pauses all in-flight tasks and returns their IDs.

```json
{
  "ok": true,
  "paused": ["task_1", "task_2"]
}
```

### `claw-forge state resume --json`

Resumes all paused tasks in the current session.

```json
{
  "ok": true,
  "resumed": ["task_1", "task_2"]
}
```

---

## Task queries and mutations

### `claw-forge state ready --json`

Returns the next wave of DAG-ready tasks (all dependencies satisfied, status `pending`).

```json
{
  "ok": true,
  "tasks": [
    {
      "id": "task_abc",
      "slug": "user-auth",
      "description": "Implement JWT-based user authentication",
      "category": "Authentication",
      "depends_on": [],
      "files": ["src/auth/**", "tests/test_auth.py"],
      "shape": "core"
    }
  ]
}
```

Returns `"tasks": []` when the DAG is empty (dispatch loop should stop).

### `claw-forge state get <id> --json`

Returns the full record for one task.

```json
{
  "ok": true,
  "task": {
    "id": "task_abc",
    "slug": "user-auth",
    "description": "Implement JWT-based user authentication",
    "status": "in_progress",
    "category": "Authentication",
    "depends_on": [],
    "files": ["src/auth/**"],
    "shape": "core",
    "last_error": null,
    "worktree_path": "/path/to/project/.claw-forge/worktrees/user-auth",
    "handoff_path": null
  }
}
```

### `claw-forge state patch <id> --status <status> --json`

Updates a task's status. Valid values for `<status>`: `pending`, `in_progress`,
`done`, `failed`, `paused`.

```json
{
  "ok": true,
  "id": "task_abc",
  "status": "done"
}
```

---

## File locking

### `claw-forge file-claim <task-id> --files <globs> --json`

Atomically reserves file-path globs for a task, preventing concurrent edits.
Fails (non-zero + `"ok": false`) if another task already holds a conflicting lock.

```json
{
  "ok": true,
  "task_id": "task_abc",
  "claimed": ["src/auth/**", "tests/test_auth.py"]
}
```

### `claw-forge file-release <task-id>`

Releases all file locks held by a task. No `--json`; exits 0 always.

---

## Git / worktree helpers

### `claw-forge git create-worktree <slug> --json`

Creates (or resumes) an isolated git worktree for the feature branch
`claw-forge/<slug>`.

```json
{
  "ok": true,
  "slug": "user-auth",
  "branch": "claw-forge/user-auth",
  "worktree_path": "/path/to/project/.claw-forge/worktrees/user-auth",
  "resumed": false
}
```

`"resumed": true` when the worktree already existed and was re-attached.

### `claw-forge git sync-worktree <slug> --json`

Rebases the feature branch onto the current `HEAD` of the target branch before
dispatch. Called immediately before the Task subagent is launched.

```json
{
  "ok": true,
  "slug": "user-auth",
  "rebased_commits": 3,
  "conflicts": []
}
```

Non-empty `"conflicts"` causes the dispatch loop to route to conflict recovery.

### `claw-forge git squash-merge <slug> --json`

Squash-merges the feature branch into the target branch after a successful task
completion.

```json
{
  "ok": true,
  "slug": "user-auth",
  "merged_into": "main",
  "sha": "deadbeef"
}
```

### `claw-forge git leak-snapshot <task-id> --json`

Snapshots the project root file tree before a Task subagent is dispatched. Used by
the post-Task leak check to detect files accidentally written outside the worktree.

```json
{
  "ok": true,
  "task_id": "task_abc",
  "snapshot_id": "snap_xyz"
}
```

### `claw-forge git leak-check <task-id> --json`

Compares the project root against the pre-dispatch snapshot and auto-stashes any
leaked files back into the worktree.

```json
{
  "ok": true,
  "task_id": "task_abc",
  "leaked_files": [],
  "stashed": []
}
```

---

## Planning

### `claw-forge plan --spec <path> --json`

Parses `<path>` (typically `app_spec.xml`) and seeds the DAG into the state DB.

```json
{
  "ok": true,
  "features_seeded": 49,
  "categories": {
    "Authentication": 5,
    "API": 12
  },
  "warnings": []
}
```

---

## Spec tooling

### `claw-forge spec validate --json`

Runs all four validator layers (schema, shape-annotation, dependency cycle check,
file-touch coverage) and returns findings.

```json
{
  "ok": true,
  "result": "PASS",
  "findings": []
}
```

On failure `"result"` is `"FAIL"` and `"findings"` lists objects with `layer`,
`feature_id`, and `message`.

---

## Boundaries audit

### `claw-forge boundaries audit --json`

Returns a read-only hotspot report scoring files by cross-boundary coupling.

```json
{
  "ok": true,
  "hotspots": [
    {
      "path": "src/core/dispatcher.py",
      "score": 0.87,
      "reason": "imported by 14 modules across 4 categories"
    }
  ]
}
```

---

## Export

### `claw-forge export <format>`

Exports session or training data. No `--json`; writes to a file and prints the path
on stdout. Formats vary by sidecar version; `jsonl` is always supported.

---

## UI

### `claw-forge ui`

Opens the Kanban UI at `http://localhost:8421` in the default browser. No `--json`;
exits 0 when the browser command succeeds. Prints the resolved URL on stdout.
