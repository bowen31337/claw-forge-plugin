# claw-forge-plugin

A Claude Code plugin that brings the [claw-forge](https://github.com/<org>/claw-forge)
autonomous coding agent harness inside your interactive Claude Code session — so every
agent invocation bills against your Claude Pro/Max subscription pool instead of the
metered Claude Agent SDK allowance.

**Status:** Pre-release. Documentation and spec only. Implementation tracked in the
plugin's own claw-forge run.

## Why

[Anthropic's policy](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan)
gives apps that use `claude-agent-sdk` or `claude -p` a limited credit allowance
**separate from your Pro/Max subscription pool**. claw-forge today uses the SDK for every
agent invocation. The plugin form moves that execution inside your CC session, where it
bills the normal way.

## How it works (in one paragraph)

You install two things: `pip install claw-forge` (the Python sidecar — state service,
Kanban UI, spec tooling, git helpers) and `/plugin install claw-forge` (this plugin —
slash commands, skills, subagent definitions, hooks). When you open a claw-forge project,
a SessionStart hook starts the sidecar in the background. You type `/claw-forge run`; a
skill instructs the host session to query the sidecar for ready tasks and dispatch them
in parallel via the Task tool. Each subagent does one feature inside an isolated git
worktree, reports back, and the host PATCHes the state DB and squash-merges. No SDK
calls anywhere — the host CC session is the only thing that ever talks to Claude.

## Documents

- **[PRD](docs/PRD.md)** — product requirements: motivation, users, goals, success
  metrics, feature inventory, sidecar contract dependencies, constraints, open questions
- **[ARCHITECTURE](docs/ARCHITECTURE.md)** — technical architecture: repo layout,
  component map, dispatch loop replacement, subagent workflow, sidecar interface,
  hooks, sandboxing changes, build/test/CI strategy, migration path, sidecar slimming
  needed in claw-forge v0.6.0

## Building this plugin

This repo is itself a greenfield claw-forge project:

1. Sidecar `claw-forge` v0.5.x is used for the bootstrap build (acknowledged one-time
   metered cost — see PRD §9 "Bootstrap chicken-and-egg").
2. `/create-spec` (a sidecar slash command in claw-forge today) turns `docs/PRD.md` into
   `app_spec.xml` with shape annotations.
3. `claw-forge plan` → DAG into the state DB.
4. `claw-forge run` builds the plugin features in parallel worktrees.
5. After v0.1.0 ships, future plugin development uses the plugin itself.

## License

Apache-2.0
