---
name: visual-review
description: Read-only reporter of visual-approval state. Compares the current baseline PNGs against the integration branch, reads visual-approvals.json, and reports each changed baseline as approved / rejected / pending with its task ID. The canonical way the pipeline learns whether a human has signed off on the visuals. Does not re-baseline (that is a human action, blocked for agents by guard-visual-update).
---

# /visual-review — Visual Approval-State Reader

## Role

The **read-only** bridge between a human's visual sign-off and the rest of the pipeline. A human
approving a screenshot is a durable artifact, not a witnessed click: approving re-baselines the PNG
and records a decision in `visual-approvals.json`. This skill *reads* that state and reports it, so
`/qa-tester` can flag what's pending and `/pr-reviewer` can gate the merge. It never blesses baselines
itself — `guard-visual-update` blocks agents from `--update-snapshots`.

If visual testing is disabled (no `Visual testing` block, or `enabled: false` in `.claude/context.md`),
report "visual testing disabled — nothing to review" and exit clean. It is inert at Tier 0.

## Permissions

✅ CAN read    : `.claude/context.md` · `visual-approvals.json` · baseline PNGs · `docs/ROADMAP.md`
✅ CAN run     : read-only git (`git diff --name-only`, `git status`, `git merge-base`)
❌ CANNOT      : write, edit, or delete any file — it is a reporter
❌ CANNOT      : run `--update-snapshots` or re-baseline (human/review-app only)

## The approval record — `visual-approvals.json`

A repo-root JSON file, keyed by **baseline id** = the snapshot path relative to the baselines dir
(e.g. `example.visual.spec.ts/home-desktop-linux.png`). Written by a human (or the Tier 3 review app),
committed alongside the re-baselined PNGs:

```json
{
  "example.visual.spec.ts/home-desktop-linux.png": {
    "decision": "approved",
    "task": "PUX-11",
    "capturedImage": "visual-review/results/output/…/home-desktop-actual.png",
    "at": "2026-07-03T15:44:03Z"
  },
  "example.visual.spec.ts/home-mobile-linux.png": {
    "decision": "rejected",
    "task": "PUX-14",
    "at": "2026-07-03T15:45:10Z"
  }
}
```

- `decision` — `approved` (blessed; PNG re-baselined) or `rejected` (must not merge).
- `task` — the roadmap task the change belongs to.
- `capturedImage` — the container-rendered candidate that was approved (parity provenance; optional).
- `at` — ISO 8601 UTC timestamp.

## Step-by-step

1. **Check enablement.** Read the `Visual testing` block in `.claude/context.md`. If absent or
   `enabled: false` → report disabled, exit clean.
2. **Find changed baselines.** Compute the set of baseline PNGs that differ from the integration
   branch (the base the PR targets, from `.claude/context.md` → Version control & forge):
   ```bash
   BASE=$(git merge-base HEAD <integration-branch>)
   git diff --name-only "$BASE" -- '<baselines-dir>/**' | grep -E '\.png$'
   ```
   Also include un-committed changes (`git status --porcelain`) so a mid-flight state is visible.
3. **Read the record.** Load `visual-approvals.json` (empty/absent = every changed baseline is
   pending).
4. **Classify each changed baseline** by its id:
   - in record as `approved` → **approved**
   - in record as `rejected` → **rejected** (blocking)
   - not in record (or changed after its record `at`) → **pending** (blocking)
5. **Report** a structured summary:
   - counts: `approved`, `rejected`, `pending`, `total changed`
   - per-baseline: id · status · task
   - an overall `gate`: `clear` only when `pending == 0 && rejected == 0`; otherwise `blocked`
     with the list of offending baselines.

When invoked autonomously (by `/qa-tester` or `/pr-reviewer`), return this as the structured result;
`gate: blocked` is what those steps act on.

## What /visual-review does NOT do

- Does not re-baseline, approve, or edit `visual-approvals.json` — reading only.
- Does not run the visual suite (that's `/qa-tester`); it reports on baselines already present.
- Does not open or block a PR itself — it hands `/pr-reviewer` the gate verdict.

## Cross-references

- Enable / scaffold: `/visual-setup`
- The guard that stops agents re-baselining: `.claude/hooks/guard-visual-update.sh`
- Human approval loop: `docs/visual-testing.md`
