# Migrating from claw-forge v0.5.x to v0.6.0 + plugin

This guide covers upgrading from the standalone sidecar (v0.5.x) to the split architecture
introduced in **claw-forge v0.6.0** plus **claw-forge-plugin v0.1.0**.

**What changes:** the agent dispatch loop moves out of the sidecar and into your Claude Code
session via a plugin. Every agent invocation now bills against your Claude Pro/Max subscription
pool instead of the metered Agent SDK allowance. The sidecar keeps all its state, spec, git, and
UI responsibilities — only the runner is gone.

---

## Step-by-step upgrade

### 1. Upgrade the sidecar

```sh
pip install -U claw-forge
```

This brings `claw-forge` v0.6.0. The sidecar CLI, state service, spec tooling, git helpers, and
Kanban UI are all present; only the SDK-based runner modules are removed.

Verify:

```sh
claw-forge --version   # should print 0.6.x
```

### 2. Install the plugin inside Claude Code

Open any Claude Code session (or a new one in your project directory) and run:

```
/plugin install claw-forge
```

Once installed, the `claw-forge-dispatch-loop` skill and all `/claw-forge` slash commands are
available in every session that opens a claw-forge project. A `SessionStart` hook also starts
the sidecar state service automatically on each session open.

### 3. Change your run habit

The primary workflow command moves from a terminal command to a slash command:

| Before (v0.5.x) | After (v0.6.0 + plugin) |
|---|---|
| `claw-forge run` | `/claw-forge run` |
| `claw-forge fix <task-id>` | `/claw-forge fix <task-id>` |
| `claw-forge merge` | `/claw-forge merge` |
| `claw-forge boundaries apply` | `/claw-forge boundaries-apply` |

All other sidecar CLI commands (`claw-forge plan`, `claw-forge state …`, `claw-forge spec …`,
`claw-forge boundaries audit`, `claw-forge export`, `claw-forge ui`) are unchanged and continue
to work in the terminal as before.

The old `claw-forge run` binary now prints a deprecation notice and exits with code 1. Pin
`claw-forge==0.5.x` if you need API-mode execution while transitioning.

### 4. Verify the sidecar starts cleanly

Open a Claude Code session in your project. The `SessionStart` hook runs
`hooks/ensure-sidecar.sh`, which:

1. Checks `claw-forge --version` is ≥ 0.6.0 (warns, does not abort if not).
2. Runs `claw-forge state start --detach` if the service is not already up.
3. Prints a banner with the state port (8420), UI port (8421), and session ID.

If you see the banner, the sidecar is healthy and `/claw-forge plan` / `/claw-forge run` are
ready to use.

### 5. Confirm state continuity

Your existing `.claw-forge/state.db` carries over unchanged — the schema is identical between
v0.5.x and v0.6.0. Any in-progress session survives the upgrade. Run `/claw-forge status` to
inspect the current session state.

---

## Config changes

### `providers:` block — now ignored

The `providers:` section in `claw-forge.yaml` (and the `pool:` section above it) is silently
ignored in v0.6.0. The plugin uses only the host Claude Code session as its model provider; there
is no multi-provider rotation.

You do **not** need to remove these blocks — leaving them in place is not an error and does not
affect behavior. If you want a cleaner config, you can delete the `pool:` and `providers:`
sections entirely.

Example of config you can safely leave or remove:

```yaml
# These sections are now ignored — safe to delete if desired
pool:
  strategy: round_robin
  failure_threshold: 5
  max_retries: 3
  recovery_timeout: 60

providers:
  claude-oauth-1:
    enabled: false
    oauth_token: ${OAUTH_TOKEN_A}
    priority: 1
    type: anthropic_oauth
  claude-oauth-2:
    enabled: true
    oauth_token: ${OAUTH_TOKEN_B}
    priority: 1
    type: anthropic_oauth
```

### `agent.isolation: container` — now ignored

The `container` isolation mode (Docker/Podman per-agent container) is removed in v0.6.0. If your
config has `agent.isolation: container`, the sidecar prints a one-line warning at startup and
treats it as `sandbox`.

The `container:` sub-block (`runtime:`, `image:`, `pull_if_missing:`, etc.) is also ignored.

```yaml
agent:
  isolation: container   # ← warning at startup; treated as sandbox in v0.6.0
  container:
    runtime: docker
    image: my-claw-forge-agent
    # ↑ entire container: block is ignored
```

The **`sandbox`** isolation mode and `sandbox.home_protection` are unchanged and remain active.
Worktree-leakage defenses (workspace-boundary directives in subagent prompts, permission prompts,
and snapshot-rollback via `claw-forge git leak-snapshot` / `leak-check`) are all present in
v0.6.0 — the host Claude Code session is now the trust boundary for agent execution.

---

## What did not change

- **State schema.** `Task`, `Session`, `Event`, and file-claims tables are identical.
- **Sidecar CLI surface.** All 20 CLI commands with `--json` output are present and stable.
- **Git / worktree machinery.** Branch naming, worktree creation, squash-merge, leak-watch, and
  cleanup behave identically.
- **Spec tooling.** `claw-forge plan --spec <path> --json` and the validator are unchanged.
- **Kanban UI.** Still served at `localhost:8421`; open via `/claw-forge ui` or `claw-forge ui`.
- **`agent.max_concurrent_agents`.** Controls the wave batch size for `/claw-forge run`, same as
  the v0.5.x runner's concurrency. Override per run with `/claw-forge run --max-concurrency N`.

---

## Troubleshooting

**`claw-forge run` prints a deprecation message**
Expected — the v0.6.0 sidecar stub exits with code 1 and points you to `/claw-forge run`.

**`/claw-forge` commands not found**
The plugin is not installed or the session predates the install. Run `/plugin install claw-forge`
and open a new session.

**Warning: `agent.isolation: container` is not supported in plugin mode**
Your `claw-forge.yaml` has `isolation: container`. Change it to `isolation: sandbox` to silence
the warning, or leave it — behavior is the same either way.

**State service not starting**
Check that `claw-forge state start --detach` succeeds in the terminal. Common causes: port 8420
already occupied by a previous run (`claw-forge state status --json` to check), or the v0.5.x
binary is still first on `PATH` (`which claw-forge` should show your v0.6.0 install).
