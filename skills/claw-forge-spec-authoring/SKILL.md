---
name: claw-forge-spec-authoring
description: Draft and edit app_spec.xml with shape annotations for spec-create, spec-fix, and spec-expand workflows
triggers:
  - claw-forge-spec-authoring
  - /claw-forge spec-create
  - /claw-forge spec-fix
  - /claw-forge spec-expand
---

## Overview

This skill guides the host session through creating or editing an `app_spec.xml` that
the claw-forge sidecar can parse, validate, and schedule. It is loaded by
`/claw-forge spec-create` (greenfield), `/claw-forge spec-import` (brownfield),
`/claw-forge spec-fix` (repair validator errors), and `/claw-forge spec-expand`
(expand a single feature into sub-features). The skill writes the spec file to
disk and displays the output path on completion.

## Steps

### Phase 1 — Gather context

1. Ask the user for a project description (or scan the existing codebase for brownfield).
2. Identify major functional categories (e.g. auth, data model, API, UI, DevOps).
3. For each category, enumerate the discrete user-visible features that belong to it.
4. Confirm the output path (default: `./app_spec.xml`) and `mode` attribute
   (`greenfield` for new projects, `brownfield` for existing codebases).

### Phase 2 — Draft the spec

1. Write a `<project_specification mode="greenfield|brownfield">` document using
   `app_spec.example.xml` as the structural template.
2. For each feature, write a `<feature index="N" shape="…">` element (add
   `plugin="<name>"` for plugin-shaped features) whose `<description>` is a single,
   testable acceptance-criterion sentence.
3. Assign initial `shape` annotations — default every feature to `shape="plugin"`;
   Phase 3.25 will downgrade where necessary.

### Phase 3 — Review and annotate

1. **Phase 3.25 — plugin-vs-core classification.** Walk every `<feature>` and apply
   the decision rules below. The dispatcher defaults to `plugin`; downgrade to `core`
   only when necessary.

   Keep `shape="plugin"` when the feature:

   - Owns an isolated vertical slice under a dedicated directory
     (`src/plugins/<name>/` or `src/features/<name>/`).
   - Creates new files only and does not modify files owned by other features.
   - Has no shared-state dependencies (middleware, global config, DB migrations).

   Downgrade to `shape="core"` when the feature:

   - Touches shared infrastructure: middleware, error handlers, JWT guards, CORS
     config, or global router registration.
   - Modifies shared design-system or global CSS files used by multiple plugins.
   - Requires a migration that alters an existing shared table schema.
   - Introduces or modifies a shared type or interface depended on by other features.

   For every `shape="core"` feature, add an explicit `touches_files` attribute using
   comma-separated repo-relative paths or glob patterns (e.g.
   `src/middleware/**,src/config/routes.py`).

2. **Phase 3.5 — overlap analysis.** Verify that no two `plugin` features claim
   overlapping files or directories.

   - Collect every claimed directory prefix and `touches_files` glob from all `plugin`
     features.
   - For each colliding pair, choose one resolution:
     - Narrow `touches_files` so the two path sets are disjoint.
     - Merge the two features into a single `<feature>` element.
     - Downgrade the broader-impact feature to `shape="core"`.
   - Confirm that no `core` feature's `touches_files` globs overlap a `plugin`
     feature's claimed directory — the core glob wins at dispatch time, so the plugin
     must avoid those paths.

### Phase 4 — Write and validate

1. Write the final `app_spec.xml` to the path confirmed in Phase 1.
2. Run `claw-forge spec validate --json` and capture the result.
3. If validator errors remain, return to the relevant phase and fix the offending elements.
4. Display the output path and a feature-count summary on success:

   ```
   app_spec.xml written → ./app_spec.xml  (N features: M core, K plugin)
   ```

## Expand Mode (triggered by /claw-forge spec-expand)

When invoked with `feature_id`, `spec_path`, and `feature_xml`, run the following
steps instead of the create/fix workflow above.

### Phase E1 — Load context

1. Read the full `app_spec.xml` at `spec_path` to understand the project, existing
   categories, and surrounding features.
2. Identify the category that contains the target feature.
3. Examine the feature's `shape`, `plugin`, and `touches_files` attributes along with
   its `<description>` to understand scope and ownership.

### Phase E2 — Generate sub-features

1. Decompose the single feature's acceptance criterion into 2–8 discrete, independently
   testable sub-features. Each sub-feature must:
   - Address exactly one observable behaviour (single-sentence rule still applies).
   - Be implementable without depending on another sub-feature in the same expansion.
   - Inherit the parent's `shape` and `plugin` attributes unless Phase E3 reclassifies it.
2. Preserve intent: every aspect of the parent's acceptance criterion must be covered by
   at least one sub-feature; nothing should be dropped silently.

### Phase E3 — Display sub-features

Display the proposed sub-features to the host session before writing anything to disk:

```
Expanding feature <feature-id>: "<original description>"

Proposed sub-features:
  [N+0]  shape="…"  <first sub-feature description>
  [N+1]  shape="…"  <second sub-feature description>
  …
```

Where `N` is the insertion point in the re-indexed sequence. Ask the user to confirm,
request edits, or cancel before proceeding.

### Phase E4 — Apply classification rules

Apply the same plugin-vs-core decision rules from Phase 3.25 to each sub-feature.
If a sub-feature must be downgraded to `shape="core"`, add an explicit `touches_files`
attribute. Run the overlap analysis from Phase 3.5 across the full updated feature list.

### Phase E5 — Write and validate

1. Replace the original `<feature index="<feature-id>" …>` element with the new
   sub-feature elements.
2. Re-index **all** `<feature>` elements in the document sequentially (1, 2, 3, …)
   to keep index values contiguous.
3. Write the updated spec back to `spec_path`.
4. Run `claw-forge spec validate --json` and fix any errors before returning.
5. Display the result:

   ```
   app_spec.xml updated → <spec_path>
   Feature <feature-id> expanded: 1 feature → N sub-features  (total: M features)
   ```

## Spec Conventions

- Each `<description>` must be a complete sentence ending with a parenthetical that
  names the observable output: e.g. "User can register with email (returns 201 with
  user_id)."
- Do not mix multiple acceptance criteria in one feature — split them into separate
  `<feature>` elements.
- `shape="plugin"` features may include a `plugin="<name>"` attribute; the dispatcher
  derives the plugin directory from it and does not require an explicit `touches_files`.
- `touches_files` uses comma-separated repo-relative paths; glob patterns are allowed.
- Aim for 100–300 features for a full application; the reference smoke-gate fixture
  uses 5 features as the minimum testable slice.
