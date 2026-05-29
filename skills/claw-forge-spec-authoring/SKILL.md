---
name: claw-forge-spec-authoring
description: Draft and edit app_spec.xml with shape annotations for spec-create and spec-fix workflows
triggers:
  - claw-forge-spec-authoring
  - /claw-forge spec-create
  - /claw-forge spec-fix
---

## Overview

This skill guides the host session through creating or editing an `app_spec.xml` that
the claw-forge sidecar can parse, validate, and schedule. It is loaded by
`/claw-forge spec-create` (greenfield), `/claw-forge spec-import` (brownfield), and
`/claw-forge spec-fix` (repair validator errors). The skill outputs the spec file to
disk and displays the output path on completion.

## Steps

### Phase 1 — Gather context

1. Ask the user for a project description (or read the existing codebase for brownfield).
2. Identify major functional categories (e.g. auth, data model, API, UI, DevOps).
3. For each category, list the discrete user-visible features that belong to it.

### Phase 2 — Draft the spec

4. Write a `<project_specification mode="greenfield|brownfield">` document.
5. For each feature, write a `<feature index="N" shape="…" touches_files="…">` element
   with a `<description>` that is a single, testable acceptance-criterion sentence.
6. Assign `shape` annotations:
   - `shape="plugin"` — the feature owns a self-contained directory; safe to parallelize.
   - `shape="core"` — the feature touches shared files; must run serially.

### Phase 3 — Review and annotate

7. **Phase 3.25 — plugin-vs-core classification.** Walk every feature and confirm the
   `shape` assignment. Downgrade `plugin` → `core` wherever `touches_files` overlaps with
   another feature's claimed files.
8. **Phase 3.5 — overlap analysis.** Check that no two `plugin`-shape features claim the
   same file. Flag collisions and adjust `touches_files` or merge features.

### Phase 4 — Write and validate

9. Write the final `app_spec.xml` to the project root (or the path specified by the user).
10. Run `claw-forge spec validate --json` and display the results.
11. If validator errors remain, return to Phase 3 and fix the offending bullets.
12. Display the output path on success.

## Spec Conventions

- Each `<description>` must be a complete sentence ending with a parenthetical that
  names the observable output (e.g. "displays X" or "exits with code 0").
- Avoid feature descriptions that mix multiple acceptance criteria — split them.
- `touches_files` uses comma-separated repo-relative paths; glob patterns are allowed.
