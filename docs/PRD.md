# claw-forge-plugin — Product Requirements Document

**Status:** Draft v0.1
**Date:** 2026-05-29
**Owner:** Bowen Li
**Target version:** plugin v0.1.0, paired with sidecar `claw-forge` v0.6.0

---

## 1. Background

Anthropic recently changed how Claude subscriptions interact with the Claude Agent SDK
([support article](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan)):
applications that invoke Claude through `claude-agent-sdk` or `claude -p` (headless mode)
receive a small, **limited credit allowance separate from the Pro/Max subscription token
pool**. Long-running autonomous agents — exactly what claw-forge orchestrates — burn
through that allowance in minutes.

claw-forge today calls `claude_agent_sdk.query()` for every feature, bugfix, code review,
boundaries refactor, and conflict-advisor invocation. Every one of those calls is now
metered against the SDK allowance, not the user's subscription pool. The economics no
longer work for the daily-driver use case.

A Claude Code **plugin**, by contrast, runs inside the user's interactive `claude` session.
Every tool call, subagent dispatch, and slash command bills against the same subscription
pool the user already pays for. Moving claw-forge's agent-invocation layer into a plugin
restores the economics.

## 2. Problem statement

Claw-forge's core value — spec → DAG → parallel autonomous agents → working code with
checkpoints, sandboxes, and a Kanban UI — is economically gated for Pro/Max subscribers.
Users have an active subscription with a generous token pool but cannot reach it from the
current `claw-forge run` execution path. The only available path today costs additional
money on top of the subscription they already hold.

## 3. Target users

**Primary:**
- Existing claw-forge users on Claude Pro or Max plans who want to keep using claw-forge
  without metered API spend on top of their subscription.
- Greenfield/brownfield authors who already work in Claude Code daily and want
  spec-driven autonomous agents inside their normal workflow.

**Secondary:**
- Teams evaluating autonomous-agent harnesses who don't want to provision separate API
  keys, multi-provider rotation, or container orchestration to try claw-forge.

**Out of scope as users (for this PRD):**
- Users who specifically want multi-provider rotation, OAuth providers, or container
  isolation — those paths remain available in sidecar `claw-forge` v0.5.x. The plugin
  does not aim to replace them.

## 4. Goals

In priority order:

1. **Token-pool parity.** Every agent invocation triggered by the plugin bills against the
   user's Claude Code subscription pool. No `claude_agent_sdk` calls anywhere in the
   plugin or its skills.
2. **Workflow parity.** Slash commands deliver the same end-to-end experience as today's
   `claw-forge plan / run / fix / merge / boundaries apply` flow. The user's mental model
   does not change.
3. **Install simplicity.** Two commands: `pip install claw-forge` and `/plugin install
   claw-forge`. No Docker, no provider config, no API keys.
4. **Behavioural parity on the non-agent surface.** Spec parsing, validation, the Kanban
   UI, the exporter, boundaries audit, and git/worktree management work identically. None
   of these touched the SDK in the first place.
5. **Stable cross-repo contract.** The sidecar's CLI becomes a documented public API. The
   plugin can be developed and shipped independently of patch-level sidecar releases.

## 5. Non-goals

- **Multi-provider key rotation.** The host CC session is the only "provider"; rotation
  is meaningless.
- **Container / Docker isolation for agents.** The host CC session is the trust boundary.
- **5-layer subprocess sandbox.** Same reason — no subprocess to sandbox.
- **Per-task cost tracking in dollars.** Subscription pool isn't itemised per
  agent invocation. Token counts can still be surfaced where the host session exposes them.
- **Backwards compatibility with `claw-forge run` from within the plugin.** Users who want
  that path keep using sidecar v0.5.x directly.
- **Training-trace capture in v0.1.** The host CC session's internal subagent message
  stream is not accessible the way SDK messages are. Deferred to a follow-up; the
  `claw_forge/training/` module stays in the sidecar but does not capture during plugin
  runs. Revisit in v0.2.
- **Replacing the sidecar Python package.** The plugin is additive. The sidecar slims
  down (see Section 8) but does not disappear.

## 6. Success metrics

| Metric | Target |
|---|---|
| Fresh install to first successful 5-feature greenfield run | ≤ 5 minutes wall-clock |
| Feature completion rate on reference spec (toy TODO app, 5 features) | ≥ 85% (parity with current `claw-forge run`) |
| Metered API spend during plugin run | $0.00 (hard invariant; any non-zero is a bug) |
| Cross-repo CI smoke test runtime | < 2 minutes per PR |
| Sidecar CLI contract surface | ≤ 20 commands, each with documented `--json` schema |
| Plugin install + `/plugin install claw-forge` success rate | ≥ 95% on stock macOS + Linux |

## 7. User-facing capabilities

This section enumerates discrete capabilities. Each bullet is intended to become one
`<feature>` element when `/create-spec` processes this PRD. Categories map to
`<category>` blocks.

### Category: Plugin installation & lifecycle

- User can install the plugin via `/plugin install claw-forge` from a registered marketplace
- Plugin manifest validates against the official `.claude-plugin/plugin.json` schema
- Plugin auto-detects claw-forge projects via the presence of `claw-forge.yaml` or `.claw-forge/state.db` in cwd
- SessionStart hook auto-starts the sidecar state service when entering a claw-forge project
- SessionStart hook detects missing sidecar CLI and prints a one-line `pip install` hint without aborting the session
- SessionStart hook version-gates the sidecar: refuses to proceed if `claw-forge --version` is below the declared minimum, printing a one-line upgrade hint
- SessionStart hook prints a brief banner showing state service port, UI port, and session ID once ready
- Plugin gracefully no-ops in non-claw-forge directories (no banner, no errors)

### Category: Slash commands — spec authoring

- User can run `/claw-forge spec-create` to interactively generate an `app_spec.xml` from a description
- User can run `/claw-forge spec-import` to import an existing project's structure into a `brownfield_manifest.json` + spec
- User can run `/claw-forge spec-validate` to run all 4 validator layers (parser + Layers 1-3 + Layer 4 shape)
- User can run `/claw-forge spec-fix` to interactively resolve validator errors
- User can run `/claw-forge spec-expand <feature-id>` to expand a single feature into sub-features

### Category: Slash commands — planning & execution

- User can run `/claw-forge plan` to parse the spec and seed the DAG into the state DB
- User can run `/claw-forge run` to start the dispatch loop in the host session
- User can run `/claw-forge run --features <ids>` to run a specific subset
- User can run `/claw-forge resume` to resume after host session interruption
- User can run `/claw-forge fix <task-id>` to enter an interactive bugfix loop on a single failure
- User can run `/claw-forge merge` to squash-merge ready feature branches to target
- User can run `/claw-forge boundaries-audit` to identify refactor hotspots (read-only)
- User can run `/claw-forge boundaries-apply <path>` to refactor one hotspot
- User can run `/claw-forge boundaries-apply --auto` to refactor hotspots serially

### Category: Slash commands — status & introspection

- User can run `/claw-forge status` to see a textual session overview
- User can run `/claw-forge session-status` to see live state of the current session (this replaces the obsolete `/claw-forge pool-status` — provider pool no longer exists)
- User can run `/claw-forge ui` to open the Kanban UI in the default browser
- User can run `/claw-forge checkpoint` to manually checkpoint all active worktrees
- User can run `/claw-forge stash-list` to list claw-forge stash entries
- User can run `/claw-forge stash-drop <ref>` to drop a stash entry
- User can run `/claw-forge worktrees-list` to list active worktrees
- User can run `/claw-forge worktrees-prune` to clean up orphaned worktrees
- User can run `/claw-forge export <format>` to export session/training data

### Category: Skills (auto-loaded by host session, not user-invoked)

- `claw-forge-dispatch-loop` skill describes the wave-by-wave Task-tool dispatch pattern
- `claw-forge-feature-implementation` skill describes the per-feature subagent workflow
- `claw-forge-conflict-recovery` skill describes how to resolve sync/merge conflicts
- `claw-forge-boundaries-refactor` skill describes the boundaries-apply pattern
- `claw-forge-spec-authoring` skill describes how to draft and edit specs
- `claw-forge-bugfix-loop` skill describes the interactive bugfix workflow

### Category: Subagents (callable via Task tool)

- `coding-feature` subagent implements one feature inside a worktree and reports back
- `bugfix-task` subagent fixes a single failed task with structured resume context
- `feature-reviewer` subagent reviews a feature branch and emits structured verdict
- `merge-conflict-resolver` subagent resolves a sync or squash-merge conflict
- `boundaries-refactor` subagent applies one canonical refactor pattern (registry / split / extract_collaborators / route_table)

### Category: Hooks

- SessionStart hook ensures the sidecar state service is running
- (Future) PreToolUse hook can enforce plugin-level guardrails on Bash commands

### Category: Documentation

- Plugin README explains install order (sidecar first, then plugin), the credit-pool motivation, and a "hello-world" walkthrough
- Plugin README links to the sidecar repo and to the `docs/sidecar-contract.md` contract surface
- Sidecar README is updated to mention the plugin as the recommended execution path for Pro/Max users
- Sidecar `CLAUDE.md` is updated to reflect the removed modules (pool, runner, container, sandbox, orchestrator)
- A user-facing migration guide is added at `docs/migrating-to-plugin.md`

## 8. Sidecar dependencies (contract surface)

The plugin depends on these sidecar CLI commands. Each must support `--json` output with
a documented schema in `claw-forge/docs/sidecar-contract.md`. Breaking changes to any of
these require a coordinated plugin release.

| Command | Purpose | Used by |
|---|---|---|
| `claw-forge --version` | Version probe | SessionStart hook |
| `claw-forge state status --json` | Is service running, on which port, for which project | SessionStart hook |
| `claw-forge state start --detach` | Boot state service in background | SessionStart hook |
| `claw-forge state ready --json` | Next batch of ready tasks (DAG-ordered) | `claw-forge-dispatch-loop` skill |
| `claw-forge state patch <id> --status <s> --json` | Update task status | dispatch & bugfix loops |
| `claw-forge state get <id> --json` | Read one task's full record | bugfix & resume flows |
| `claw-forge file-claim <task-id> --files <globs> --json` | Atomic file lock | dispatch loop pre-Task |
| `claw-forge file-release <task-id>` | Release locks | dispatch loop post-Task |
| `claw-forge git create-worktree <slug> --json` | Create/resume worktree | dispatch & bugfix loops |
| `claw-forge git sync-worktree <slug> --json` | Pre-dispatch sync with target | dispatch loop |
| `claw-forge git squash-merge <slug> --json` | Squash-merge to target after success | post-feature merge |
| `claw-forge git leak-snapshot <task-id> --json` | Snapshot project root before Task dispatch | dispatch loop (pre-Task) |
| `claw-forge git leak-check <task-id> --json` | Compare project root post-Task; auto-stash leaks | dispatch loop (post-Task) |
| `claw-forge state resume --json` | Resume paused tasks in the session | `/claw-forge resume` |
| `claw-forge state stop-all --json` | Pause all in-flight tasks | host-session interrupt path |
| `claw-forge plan --spec <path> --json` | Parse spec + seed DAG | `/claw-forge plan` |
| `claw-forge spec validate --json` | Run all validator layers | `/claw-forge spec-validate` |
| `claw-forge export <format>` | Export session/training data | `/claw-forge export` |
| `claw-forge ui` | Open Kanban UI in browser | `/claw-forge ui` |
| `claw-forge boundaries audit --json` | Read-only hotspot report | `/claw-forge boundaries-audit` |

## 9. Constraints

- **Hard invariant: no `claude_agent_sdk` imports anywhere in the plugin tree.** CI grep
  check on every PR. This is the primary differentiator from the sidecar.
- **Plugin manifest** must conform to the current `.claude-plugin/plugin.json` schema.
- **All agent work happens via Task subagents, slash commands, or skills loaded into the
  host CC session.** No subprocess agents.
- **Sidecar `claw-forge` CLI is assumed to be on `$PATH`.** Plugin degrades to a
  one-line install hint if missing — never silent failure.
- **Plugin is markdown + shell + plugin.json.** No Python in the plugin tree. (The
  contract-surface CLI calls happen via Bash + sidecar binary.)
- **Bootstrap chicken-and-egg.** The first plugin build will be done using *today's*
  `claw-forge run` (metered API). This is a one-time cost and an explicit accepted
  constraint. Subsequent plugin development happens via the plugin itself.

## 10. Open questions

1. Should `/claw-forge run` block the host session until completion, or return after
   kicking off the first batch and let the user invoke `/claw-forge status` to poll?
   **Tentative:** block, because Task tool calls are synchronous from the host's
   perspective anyway. Revisit if it feels bad in practice.
2. Should the plugin ship with a recommended marketplace registration from day 1, or
   require `/plugin marketplace add <url>` first? **Tentative:** direct repo install for
   v0.1, marketplace registration in v0.2.
3. Training-trace recovery — drop entirely, defer to v0.2 with a host-session-message
   capture hook, or build a lightweight per-Task input/output recording? **Tentative:**
   defer to v0.2.
4. Should subagents (`coding-feature`, `bugfix-task`, etc.) be plugin-declared in
   `agents/`, or should the host session invoke `general-purpose` with a skill providing
   the prompt template? **Leaning toward** plugin-declared so the prompts are stable and
   versioned with the plugin.

## 11. Out of scope for v0.1

- Any non-Claude-Code surface (no Cursor, no Codex, no other host environment)
- Telemetry, analytics, or anonymous usage reporting
- Public marketplace listing (manual install via repo URL is acceptable for v0.1)
- Multi-language UI (English only)
- Cost dashboards in the Kanban UI (subscription pool isn't per-task itemised)

## 12. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Anthropic changes plugin token billing | Low | High | Watch announcements; sidecar v0.5.x path remains available |
| Sidecar CLI contract drift across releases | Medium | Medium | Documented `--json` contract + cross-repo CI smoke test |
| Host CC session Task-tool concurrency limit too low to match asyncio dispatcher throughput | Medium | Medium | Wave-by-wave dispatch with batch size capped at plugin config; measure on reference spec |
| Subagent quality regression vs SDK runner | Medium | Medium | Reference-spec completion-rate gate in CI |
| User confusion about which path to use (sidecar `run` vs plugin `/run`) | High | Low | README clarity + migration guide + sidecar README updates |
