---
name: claw-forge-boundaries-refactor
description: Sequential refactor loop applying one canonical hotspot pattern at a time; routes each apply to the boundaries-refactor subagent and displays per-hotspot verdict
triggers:
  - claw-forge-boundaries-refactor
  - /claw-forge boundaries-apply
---

## Overview

This skill drives the sequential refactor loop used by `/claw-forge boundaries-apply`.
It reads the boundaries audit report for the target hotspot, selects the recommended
pattern, and routes execution to the `boundaries-refactor` subagent to perform the
actual edit. The four canonical patterns are: `registry`, `split`,
`extract_collaborators`, and `route_table`. The skill displays the per-hotspot refactor
verdict once the subagent returns.

## Steps

1. **Load the audit report.** Read the hotspot entry produced by
   `claw-forge boundaries audit --json` for the target path. Note the recommended
   pattern and the score breakdown.

2. **Select the pattern** from the audit report entry:
   - `registry` — a single dispatcher maps string keys to handler functions/classes;
     new entries are added by registration, not `elif` chains.
   - `split` — a file or module that has grown beyond a single responsibility is
     divided along its natural seams into two or more focused units.
   - `extract_collaborators` — logic that calls into many unrelated subsystems is
     extracted into a collaborator object that owns those relationships.
   - `route_table` — URL/event routing expressed as a data table rather than nested
     conditionals.

3. **Dispatch the `boundaries-refactor` subagent:**

   ```
   Task(
     subagent_type="boundaries-refactor",
     prompt=<hotspot path, recommended pattern, score breakdown, and touches_files constraints>
   )
   ```

4. **Collect the subagent result.** The `boundaries-refactor` subagent returns:

   ```json
   {
     "path": "<hotspot-path>",
     "pattern": "<pattern-name>",
     "status": "applied" | "skipped" | "failed",
     "tests_passed": true | false,
     "notes": "<one-line summary>"
   }
   ```

5. **Display the per-hotspot refactor verdict** including `path`, `pattern`, `status`,
   and whether tests passed.

## Auto Mode

When `/claw-forge boundaries-apply --auto` is used, this skill repeats steps 1–5 for
each hotspot in the audit report, in descending score order. It stops on the first
`failed` verdict and reports remaining hotspots as `skipped`.
