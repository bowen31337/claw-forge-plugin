---
name: claw-forge-boundaries-refactor
description: Sequential refactor loop applying one canonical hotspot pattern at a time
triggers:
  - claw-forge-boundaries-refactor
  - /claw-forge boundaries-apply
---

## Overview

This skill drives the sequential refactor loop used by `/claw-forge boundaries-apply`.
It receives a hotspot path from the boundaries audit report and applies one of four
canonical refactor patterns: `registry`, `split`, `extract_collaborators`, or
`route_table`. Each apply is confirmed by the project's test suite before proceeding.

## Steps

1. **Load the audit report.** Read the hotspot entry produced by
   `claw-forge boundaries audit --json` for the target path. Note the recommended
   pattern and the score breakdown.

2. **Select the pattern.**
   - `registry` — a single dispatcher maps string keys to handler functions/classes;
     new entries are added by registration, not `elif` chains.
   - `split` — a file or module that has grown beyond a single responsibility is
     divided along its natural seams into two or more focused units.
   - `extract_collaborators` — logic that calls into many unrelated subsystems is
     extracted into a collaborator object that owns those relationships.
   - `route_table` — URL/event routing expressed as a data table rather than nested
     conditionals.

3. **Apply the refactor** to the hotspot path. Use Read, Write, Edit, and Grep.
   Do not change public API surfaces unless the task record's `touches_files` permits it.

4. **Run tests.** Execute the project's test command. The refactor must leave tests
   green; roll back and try a narrower approach if they fail.

5. **Commit the refactor:**
   ```sh
   git commit -m "refactor(<path>): apply <pattern> pattern"
   ```

6. **Emit the per-hotspot refactor verdict:**
   ```json
   {
     "path": "<hotspot-path>",
     "pattern": "<pattern-name>",
     "status": "applied" | "skipped" | "failed",
     "tests_passed": true | false,
     "notes": "<one-line summary>"
   }
   ```

## Auto Mode

When `/claw-forge boundaries-apply --auto` is used, this skill repeats steps 1–6 for
each hotspot in the audit report, in descending score order. It stops on the first
`failed` verdict and reports remaining hotspots as `skipped`.
