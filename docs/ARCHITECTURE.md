# claw-forge-plugin — Technical Architecture

**Status:** Draft v0.1
**Date:** 2026-05-29
**Companion:** [PRD.md](./PRD.md)
**Sidecar contract:** `<claw-forge>/docs/sidecar-contract.md` (added in sidecar v0.6.0)

---

## 1. System overview

```
┌────────────────────────────────────────────────────────────────────┐
│ User's Claude Code session (Pro/Max — token pool covered)          │
│                                                                      │
│  /claw-forge run ──┐                                                │
│                    │                                                 │
│                    ▼                                                 │
│   Skill: claw-forge-dispatch-loop  (loaded into host context)       │
│                    │                                                 │
│   ┌────────────────┴────────────────┐                               │
│   │  Host session loops:             │                               │
│   │   1. claw-forge state ready --json  (read next batch)           │
│   │   2. For each ready task:                                       │
│   │      claw-forge file-claim → claw-forge git create-worktree     │
│   │      → claw-forge git sync-worktree                             │
│   │   3. Emit N parallel Task(subagent_type=coding-feature, …)      │
│   │   4. Collect results; PATCH state; release locks                │
│   │   5. claw-forge git squash-merge on success                     │
│   │   6. Goto 1 until empty                                         │
│   └─────────────────────────────────┘                               │
│                                                                      │
│  Parallel subagents (Task tool):                                    │
│   ┌───────────┐  ┌───────────┐  ┌───────────┐                       │
│   │ feature 1 │  │ feature 2 │  │ feature 3 │ …                     │
│   └─────┬─────┘  └─────┬─────┘  └─────┬─────┘                       │
└─────────┼──────────────┼──────────────┼──────────────────────────────┘
          │              │              │
          │   Bash + sidecar CLI calls (HTTP to localhost:8420 underneath)
          │              │              │
          ▼              ▼              ▼
┌────────────────────────────────────────────────────────────────────┐
│  Sidecar (claw-forge Python package, slimmed in v0.6.0)            │
│                                                                      │
│   ┌────────────────────────────────────────────────────────────┐    │
│   │ State service (FastAPI + aiosqlite + WebSocket)             │    │
│   │   localhost:8420                                            │    │
│   └────────────────────────────────────────────────────────────┘    │
│   ┌────────────────────────────────────────────────────────────┐    │
│   │ Kanban UI (React + Vite, served on localhost:8421)         │    │
│   └────────────────────────────────────────────────────────────┘    │
│   ┌────────────────────────────────────────────────────────────┐    │
│   │ Spec parser, validator, exporter, boundaries audit,         │    │
│   │ git/worktree helpers, slug, leak-watch, cleanup             │    │
│   └────────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
```

**Key invariant:** the only process that ever invokes Claude is the user's interactive
`claude` CLI (the host session). The sidecar is pure state, IO, and shell — no SDK
imports, no API keys, no `claude_agent_sdk` calls.

## 2. Repository layout

```
claw-forge-plugin/
├── .claude-plugin/
│   └── plugin.json
├── commands/                          # slash commands
│   ├── plan.md
│   ├── run.md
│   ├── resume.md
│   ├── fix.md
│   ├── merge.md
│   ├── status.md
│   ├── ui.md
│   ├── checkpoint.md
│   ├── spec-create.md
│   ├── spec-import.md
│   ├── spec-validate.md
│   ├── spec-fix.md
│   ├── spec-expand.md
│   ├── stash-list.md
│   ├── stash-drop.md
│   ├── worktrees-list.md
│   ├── worktrees-prune.md
│   ├── export.md
│   ├── boundaries-audit.md
│   ├── boundaries-apply.md
│   └── session-status.md
├── skills/
│   ├── claw-forge-dispatch-loop/
│   │   └── SKILL.md
│   ├── claw-forge-feature-implementation/
│   │   └── SKILL.md
│   ├── claw-forge-conflict-recovery/
│   │   └── SKILL.md
│   ├── claw-forge-boundaries-refactor/
│   │   └── SKILL.md
│   ├── claw-forge-spec-authoring/
│   │   └── SKILL.md
│   └── claw-forge-bugfix-loop/
│       └── SKILL.md
├── agents/                            # plugin-declared subagent types
│   ├── coding-feature.md
│   ├── bugfix-task.md
│   ├── feature-reviewer.md
│   ├── merge-conflict-resolver.md
│   └── boundaries-refactor.md
├── hooks/
│   ├── hooks.json
│   └── ensure-sidecar.sh
├── tests/
│   ├── reference-specs/
│   │   └── todo-app-5features/
│   │       └── app_spec.xml
│   └── smoke/
│       └── run-reference-spec.sh
├── docs/
│   ├── PRD.md                         # this PRD
│   ├── ARCHITECTURE.md                # this doc
│   └── migrating-to-plugin.md
├── CI/
│   └── github-actions.yml
├── LICENSE
└── README.md
```

## 3. Component map

### 3.1 Plugin manifest

`.claude-plugin/plugin.json`:

```json
{
  "name": "claw-forge",
  "version": "0.1.0",
  "description": "Autonomous coding agent harness — runs inside your Claude Code session, billed against your Pro/Max subscription pool",
  "author": { "name": "ClawInfra", "email": "alex.chen31337@gmail.com" },
  "homepage": "https://github.com/<org>/claw-forge-plugin",
  "repository": "https://github.com/<org>/claw-forge-plugin",
  "license": "Apache-2.0",
  "keywords": ["autonomous", "agent", "spec-driven", "orchestration"]
}
```

Plugin version starts at 0.1.0 (independent of sidecar's 0.5.x).

### 3.2 Slash commands

Each `commands/<name>.md` is a markdown file the host session reads when the user types
`/<name>`. It contains imperative instructions + the underlying skill invocation. Pattern:

```markdown
# /claw-forge run

Drives the dispatch loop for the current claw-forge session.

## Steps

1. Verify cwd is a claw-forge project (`test -f claw-forge.yaml`).
2. Verify sidecar state service is responsive (`claw-forge state status --json`).
3. Load skill: `claw-forge-dispatch-loop`.
4. Follow that skill's instructions until completion or user interrupt.

## Args

- `--features <id1,id2,...>` — restrict to a subset
- `--max-concurrency <N>` — override config (default from claw-forge.yaml)
```

Commands stay thin — they delegate to skills for the actual workflow logic.

### 3.3 Skills

| Skill | Triggers | Body summary |
|---|---|---|
| `claw-forge-dispatch-loop` | Loaded by `/claw-forge run` and `/claw-forge resume` | The wave-by-wave dispatch pattern: query ready → parallel Task calls → PATCH back → squash-merge → loop |
| `claw-forge-feature-implementation` | Loaded by `coding-feature` subagent prompt | What a feature subagent should do: cd worktree, implement, test, checkpoint, return |
| `claw-forge-conflict-recovery` | Loaded when sidecar reports `sync_conflict` or `merge_failed` | How to inspect the conflict, resolve markers, re-run tests |
| `claw-forge-boundaries-refactor` | Loaded by `/claw-forge boundaries-apply` | Sequential refactor loop, one hotspot at a time |
| `claw-forge-spec-authoring` | Loaded by `/claw-forge spec-create` and `/claw-forge spec-fix` | How to draft and edit `app_spec.xml` with shape annotations |
| `claw-forge-bugfix-loop` | Loaded by `/claw-forge fix <task-id>` | Interactive bugfix workflow with resume context |

### 3.4 Subagents (Task-tool callable types)

Each `agents/<name>.md` has frontmatter:

```yaml
---
name: coding-feature
description: Implements one feature inside a claw-forge worktree end-to-end
model: sonnet
---
```

…followed by the system prompt for that subagent. The dispatch skill calls
`Task(subagent_type="coding-feature", prompt=<rendered-task-prompt>)`.

| Subagent | Purpose | Model | Tools |
|---|---|---|---|
| `coding-feature` | Implement one feature in a worktree | sonnet | Read, Write, Edit, Bash, Grep |
| `bugfix-task` | Fix one failed task with resume context | sonnet | Read, Write, Edit, Bash, Grep |
| `feature-reviewer` | Review a feature branch, emit verdict | sonnet | Read, Bash, Grep |
| `merge-conflict-resolver` | Resolve conflict markers in a worktree | sonnet | Read, Write, Edit, Bash |
| `boundaries-refactor` | Apply one canonical refactor pattern | sonnet | Read, Write, Edit, Bash, Grep |

Model selection is per-subagent in frontmatter — opus for harder work later if needed.

### 3.5 Hooks

`hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/ensure-sidecar.sh\"",
            "async": false
          }
        ]
      }
    ]
  }
}
```

`hooks/ensure-sidecar.sh` is a small POSIX shell script. See Section 7 for its logic.

## 4. Dispatch loop replacement (the heart of the design)

**Today (in sidecar `claw_forge/orchestrator/dispatcher.py`):**

```python
async with asyncio.TaskGroup() as tg:
    while ready := await scheduler.get_ready_tasks():
        for task in ready:
            tg.create_task(run_one_task(task))  # run_agent → claude_agent_sdk.query
```

**Plugin replacement (in `skills/claw-forge-dispatch-loop/SKILL.md`):**

The skill instructs the host session to perform the loop in plain English / pseudo-bash.
The host session is the actor; Task tool parallel calls provide the concurrency.

Pseudo-flow the skill encodes:

```
LOOP:
  batch = `claw-forge state ready --json --limit ${MAX_BATCH}`
  if batch is empty:
    break

  # Pre-dispatch: claim files, create+sync worktrees, snapshot for leak detection
  for task in batch:
    `claw-forge file-claim ${task.id} --files ${task.touches_files} --json`
    if claim conflicted:
      defer task to next wave
      continue

    `claw-forge git create-worktree ${task.slug} --json`
    sync = `claw-forge git sync-worktree ${task.slug} --json`
    if sync had unresolvable conflict:
      PATCH task → failed with sync_conflict
      release file-claim
      continue

    # Baseline project-root state so we can detect agent leaks afterwards
    `claw-forge git leak-snapshot ${task.id} --json`

  # Dispatch: parallel Task calls in a single response
  EMIT (single response, multiple tool calls):
    Task(subagent_type="coding-feature", prompt=render(task1))
    Task(subagent_type="coding-feature", prompt=render(task2))
    Task(subagent_type="coding-feature", prompt=render(task3))
    …

  # Collect: for each Task result
  for (task, result) in zip(batch, results):
    # Leak check (auto-stashes anything written outside the worktree)
    `claw-forge git leak-check ${task.id} --json`

    if result.success:
      `claw-forge state patch ${task.id} --status completed --json`
      `claw-forge git squash-merge ${task.slug} --json`
      handle squash-merge result (success / conflict → conflict-recovery skill)
    else:
      `claw-forge state patch ${task.id} --status failed --error '${result.error}' --json`
    `claw-forge file-release ${task.id}`

  goto LOOP
```

### 4.1 Concurrency model

Claude Code's `Task` tool can issue parallel subagent calls in a single assistant response.
The skill instructs the host session to emit all batch tasks in one response. The host
waits until every subagent returns before processing the batch and looping. This is
**wave-by-wave dispatch**: less responsive than asyncio's streaming dispatch, but matches
the substrate without a custom event loop.

`MAX_BATCH` defaults to the sidecar's `agent.max_concurrency` value (read at loop start).
The plugin does not introduce its own concurrency knob in v0.1.

### 4.2 Single-flight for `shape="core"` tasks

The shape-aware filter that today lives in `Scheduler.get_ready_tasks` survives untouched
— `claw-forge state ready --json` returns at most one core-shape task per wave when any
core task is already running. The plugin treats this as a black box; the sidecar enforces.

### 4.3 Resume preference & sync

Pre-dispatch worktree sync (`claw-forge git sync-worktree`) wraps the same logic as
sidecar v0.5.x. Conflicts during sync map to a structured `resume_conflict:` error
returned in the JSON envelope; the dispatch loop skill recognises that envelope shape and
either (a) bumps `merge_retry_count` and re-dispatches into the conflict-bearing
worktree, OR (b) on cap-hit, marks the task failed with the conflict-recovery skill
suggested as next step.

## 5. Per-feature subagent workflow

A `coding-feature` subagent invocation receives this prompt from the dispatch skill:

```
You are implementing one feature for a claw-forge project.

## Workspace boundary (CRITICAL)
Your working directory is your assigned git worktree. All file edits must happen
inside it. Do not write anywhere else.

## Task
{task.description}

## Category context
{task.category_text}

## Acceptance criteria
{task.acceptance_criteria}

## Files you are claimed to touch
{task.touches_files}

## Resume context (if applicable)
{prior_commits, last_error, HANDOFF.md contents}

## Steps
1. cd into the worktree at {worktree_path}
2. Implement the feature
3. Commit checkpoints as you go (use `git commit` with a `Phase: <step>` trailer)
4. Run the project's test command and confirm pass
5. Emit a final structured summary on stdout in this shape:
   {"status": "success" | "failure", "commits": [...], "tests_passed": bool, "notes": "..."}
```

The skill `claw-forge-feature-implementation` is auto-loaded into the subagent context
via the agent definition's standard skill-trigger keywords. The subagent uses Read /
Write / Edit / Bash / Grep — no `claude_agent_sdk`, no MCP, no special tooling beyond
what Claude Code already provides.

## 6. Sidecar interface (the contract)

The plugin interacts with the sidecar exclusively through:

1. **The `claw-forge` CLI on `$PATH`.** Every JSON-emitting subcommand listed in PRD
   §8 is part of the contract. Schemas are documented in
   `<claw-forge>/docs/sidecar-contract.md`.
2. **HTTP to `localhost:8420`.** Only the Kanban UI (a browser, not the host session)
   uses this directly. Subagents do not call HTTP — they call the CLI, which calls HTTP
   internally. This keeps the contract surface to one form.
3. **HTTP to `localhost:8421`.** Kanban UI only.

The plugin never reads or writes `.claw-forge/state.db` directly. The state service is
the single writer.

## 7. SessionStart hook (`ensure-sidecar.sh`)

POSIX shell script. Logic (pseudo):

```sh
#!/usr/bin/env sh
set -eu

# 1. Are we in a claw-forge project? If not, silently exit.
if [ ! -f "./claw-forge.yaml" ] && [ ! -d "./.claw-forge" ]; then
  exit 0
fi

# 2. Is the sidecar CLI on PATH?
if ! command -v claw-forge >/dev/null 2>&1; then
  echo "[claw-forge plugin] sidecar CLI not found. Install: pip install claw-forge"
  exit 0   # do not abort the session
fi

# 3. Version gate.
MIN_SIDECAR="0.6.0"
CURRENT="$(claw-forge --version 2>/dev/null | awk '{print $NF}')"
if ! "$CLAUDE_PLUGIN_ROOT/hooks/version-gte.sh" "$CURRENT" "$MIN_SIDECAR"; then
  echo "[claw-forge plugin] sidecar $CURRENT is older than required $MIN_SIDECAR."
  echo "                   Upgrade: pip install -U 'claw-forge>=$MIN_SIDECAR'"
  exit 0
fi

# 4. Is the state service running for this project?
STATUS="$(claw-forge state status --json 2>/dev/null || echo '{}')"
RUNNING="$(printf '%s' "$STATUS" | jq -r '.running // false')"
if [ "$RUNNING" != "true" ]; then
  claw-forge state start --detach >/dev/null 2>&1 || {
    echo "[claw-forge plugin] failed to start state service. Try: claw-forge state start"
    exit 0
  }
fi

# 5. Banner.
PORT="$(claw-forge state status --json | jq -r '.port')"
UI_PORT="$(claw-forge state status --json | jq -r '.ui_port // empty')"
SESSION="$(claw-forge state status --json | jq -r '.session_id // "(no session yet)"')"
echo "[claw-forge] sidecar ready  state=:$PORT ui=:${UI_PORT:-—} session=$SESSION"
```

`hooks/version-gte.sh` is a 5-line semver-comparator helper.

## 8. State service interaction

Direct file or HTTP access from skills is forbidden by convention; everything goes through
the sidecar CLI. Rationale: the CLI is the contract; HTTP shape can change without
breaking the plugin as long as the CLI surface stays stable.

The sidecar's existing endpoints (PATCH task, POST file-claims, WebSocket /ws) are
unchanged. The CLI subcommands are mostly already present in
`claw_forge/state/cli.py` — those that aren't get added in sidecar v0.6.0 as part of
hardening the contract surface.

## 9. Worktree management

Unchanged in shape:

- One worktree per task at `.claw-forge/worktrees/<slug>/`
- Slug generation via `claw_forge/git/slug.py` (sidecar)
- Branch name `feat/<category>-<slug>`
- Pre-dispatch sync with `target_branch`
- Post-success squash-merge to target with structured trailer
- Smart-mode startup cleanup (preserve / salvage / remove)

The plugin invokes worktree operations via `claw-forge git ...` subcommands. The sidecar
git helpers (`branching.py`, `commits.py`, `merge.py`, `cleanup.py`, `leak_watch.py`)
stay as-is — they do not use the SDK.

`git/conflict_advisor.py` (which today uses `claude_agent_sdk`) is removed from the
sidecar in v0.6.0. Its role moves into the plugin's `claw-forge-conflict-recovery`
skill, which the host session loads when sidecar emits a conflict.

## 10. Permission & trust model

**Removed from v0.5.x:**
- `agent/sandbox.py` (macOS sandbox-exec / Linux bwrap)
- `agent/container.py` (Docker / Podman isolation)
- `agent/permissions.py` (SDK CanUseTool hooks)

**Why removed:** the host CC session is the trust boundary. Subagents called via Task
tool inherit the session's permission model — including the user's explicit allow/deny
choices and the host's permission-mode policy. There is no separate subprocess for
sandbox-exec to wrap.

**What replaces them:**
- The workspace-boundary directive in each subagent prompt (Section 5) tells the
  subagent to cd into the worktree and stay there.
- The host session's normal permission system handles tool gating.
- `git/leak_watch.py` (sidecar) is exposed via two CLI subcommands —
  `claw-forge git leak-snapshot <task-id>` (called pre-Task) and
  `claw-forge git leak-check <task-id>` (called post-Task). The dispatch skill invokes
  both around every Task tool call; leaked writes are auto-stashed as
  `claw-forge-leak-<task-id>-<ts>` for forensic recovery. Logic is unchanged from
  v0.5.x; only the invocation surface moves from a Python `finally` block to skill-driven
  CLI calls.

**Net effect:** simpler, but trust the boundary the user already trusts (their CC session
permission model). Users wanting kernel-level isolation use sidecar v0.5.x.

## 11. Build, lint, and CI

**Plugin repo CI matrix (GitHub Actions):**

1. **Plugin manifest validation** — JSON schema check on `plugin.json`.
2. **Markdown lint** — `markdownlint` over `commands/`, `skills/`, `agents/`, `docs/`.
3. **Shell lint** — `shellcheck` on `hooks/*.sh`.
4. **Skill structural self-tests** — each skill ships with a fixture in `tests/skills/`
   asserting frontmatter fields, required sections, and trigger-keyword presence.
   No LLM invocation in CI (would defeat the no-`claude -p` invariant). Skills that
   require behavioural verification are exercised in the manual pre-release pass.
5. **Cross-repo CLI-contract smoke test** — checkout sidecar at min declared version +
   at HEAD; boot `claw-forge state start`; run a script that calls every contract-surface
   command from PRD §8 with synthetic args and asserts the documented JSON shape.
   No agent dispatch in CI; the dispatch loop itself is exercised in manual pre-release.
6. **No-SDK invariant grep** — `grep -rE 'claude_agent_sdk|claude-agent-sdk|claude -p' .`
   over the plugin tree (excluding `docs/` which references them for context) returns
   nothing. Hard fail otherwise.

## 12. Testing strategy

**Unit-equivalent:**
- Plugin manifest schema validation
- `version-gte.sh` semver-comparator standalone tests
- Each slash command renders without errors (markdown lint + frontmatter validation)
- Each agent file has valid frontmatter (name, description, model)

**Integration (CI-safe — no LLM invocation):**
- SessionStart hook executes against a fresh tmpdir (no claw-forge project) and exits 0
  silently
- SessionStart hook executes against a tmpdir with `claw-forge.yaml` and successfully
  boots the sidecar (or prints the right hint when sidecar is absent)
- CLI contract smoke test (PRD §8) — every contract command called with synthetic args,
  JSON shape asserted

**Manual / pre-release (requires LLM invocation, deliberately not in CI):**
- Reference-spec end-to-end — 5-feature toy greenfield run through `/claw-forge plan` →
  `/claw-forge run` → `/claw-forge merge`, validating feature-completion rate ≥ 85%
- A "hello world" greenfield run through the plugin's full flow on macOS and Linux,
  validating each slash command works
- Browser-test the Kanban UI updates live during a plugin-driven run
- Migration walkthrough from sidecar v0.5.x → v0.6.0 + plugin v0.1.0

## 13. Migration path (for existing claw-forge v0.5.x users)

`docs/migrating-to-plugin.md` (to be authored as a feature):

1. `pip install -U claw-forge` (will bring v0.6.0)
2. Note: pool config (`providers:` block in `claw-forge.yaml`) is now ignored; remove or
   leave — it's not an error.
3. `agent.isolation: container` setting is now ignored (with a one-line warning at
   sidecar startup if set).
4. Inside Claude Code: `/plugin install claw-forge` (after the marketplace is added).
5. Habit changes: `claw-forge run` → `/claw-forge run`. Same for `fix`, `merge`,
   `boundaries apply`.
6. Existing `.claw-forge/state.db` continues to work — schema unchanged.

## 14. Sidecar slimming (v0.6.0 — happens in `claw-forge` repo, listed here for visibility)

These directories are deleted in sidecar v0.6.0. They live in the sidecar repo, not the
plugin repo, so the actual edits happen there — this list exists so the plugin
implementation can verify the contract surface assumed in this doc.

**Deleted from `claw_forge/`:**
- `pool/` — provider rotation, router, circuit breaker, usage tracker
- `agent/runner.py`, `agent/runner_*` — SDK wrapper
- `agent/container.py` — Docker/Podman isolation
- `agent/sandbox.py` — sandbox-exec / bwrap profiles
- `agent/permissions.py` — SDK CanUseTool hooks
- `orchestrator/dispatcher.py`, `orchestrator/task_handler.py`,
  `orchestrator/run_cli.py`, `orchestrator/checkpointing.py`
- `mcp/sdk_server.py`, `mcp/feature_mcp.py`
- `git/conflict_advisor.py` (logic moves to plugin skill)
- `boundaries/apply.py` (logic moves to plugin command + skill)
- `boundaries/classifier.py` (logic moves to a plugin subagent type)
- `bugfix/cli.py` `run` path (replaced by `/claw-forge fix`)

**Survives unchanged:**
- `state/` (service, models, scheduler, client, cli)
- `spec/` (parser, validator, cli)
- `git/` (slug, branching, commits, merge, leak_watch, cleanup, cli, stash_cli, merge_cli)
- `boundaries/walker.py`, `signals.py`, `scorer.py`, `audit.py`, `report.py` (read-only audit)
- `exporter.py`, `export_cli.py`
- `ui_cli.py`, `ui_dist/`
- `training/` (kept for export of historical traces; capture is dormant in v0.6.0)
- `config.py`, `_console.py`, `cli.py` (with `run` and `fix` subcommands removed)

**Sidecar `claw-forge run` becomes:** a stub that prints "deprecated; use the plugin's
`/claw-forge run`. If you need API-mode execution, pin `claw-forge==0.5.x`." Exit 1.

## 15. Open architectural questions

1. **MCP server option (Approach C from brainstorm).** Should the sidecar additionally
   expose state-service operations as an MCP server, declared in the plugin manifest? It
   would give typed tool inputs and avoid shell-quoting in skill bodies. **Deferred to
   v0.2** — the CLI contract is sufficient for v0.1.
2. **Plugin-declared vs general-purpose subagents.** Confirmed plugin-declared in
   §3.4 above. Open: do we accept a small overhead from extra agent file loads at session
   start? Likely yes; revisit if startup latency becomes noticeable.
3. **Host session interruption mid-loop.** If the user Ctrl-C's during a wave, in-flight
   subagents are cancelled by Task tool semantics; the state service still holds
   `running` rows. `/claw-forge resume` runs the smart-cleanup logic and re-enters.
   This is consistent with sidecar's existing crash-recovery surface.
4. **Wave batch size.** Default to sidecar's `agent.max_concurrency`. Allow override
   via `/claw-forge run --max-concurrency N`. Needs measurement on the reference spec
   to find a sane default for v0.1.
5. **Training-trace capture under Task-tool dispatch.** Each subagent returns one final
   result; intermediate messages are not directly visible to the host. Options for v0.2:
   (a) capture Task prompt + final result only, (b) require subagents to print
   structured logs to stdout that the host parses + posts to the state service, (c)
   wait for Claude Code to expose subagent message streams.

## 16. Non-goals (architectural)

- No new state schema. Plugin uses sidecar's existing `Task`, `Session`, `Event`, file-claims tables.
- No new ports. State service stays on 8420; UI on 8421. Plugin does not bind any port.
- No background process owned by the plugin. The sidecar owns its daemons; the plugin is
  pure config + skills + commands triggered by user action.
- No vendored Python. The plugin is markdown + shell, period.
