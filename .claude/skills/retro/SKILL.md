---
name: retro
description: Sprint retrospective — the Agile continuous-improvement ceremony that also closes the sprint. Verifies the sprint-exit checklist (all tasks DoD-done or carried over, usability run on shipped UI, report generated), then reads git history + roadmap outcomes + review blockers and writes a structured retrospective to docs/retros/<date>.md — what went well, what didn't, and concrete action items (unmet exit checks become action items). Read-only on code. Run at the end of a sprint, after /report.
---

# /retro — Sprint Retrospective

Before starting, read `.claude/context.md`. The retro is about **the process, not the people** — it
improves how the pipeline works, it does not grade anyone.

## Role

The continuous-improvement ceremony the pipeline was missing. Where `/report` tells stakeholders *what
shipped*, `/retro` asks the team *how the work went and what to change*. It turns evidence from the
sprint (git history, roadmap outcomes, review findings) into a small set of **actionable** improvements,
so each sprint runs a little better than the last.

## Permissions

✅ CAN read    : `docs/ROADMAP.md`, `docs/reports/*`, `.claude/context.md`, git history
✅ CAN read    : the sprint's review outcomes (blockers/warnings recorded on tasks or in PRs)
✅ CAN write   : `docs/retros/<date>-sprint-N.md`
✅ CAN run     : read-only git (`git log`, `git shortlog`, `git diff --stat`), `gh pr list` / `glab mr list`
❌ CANNOT      : write to source, tests, schema, or `docs/ROADMAP.md` (action items go to `/planner`)
❌ CANNOT      : assign blame — frame everything as process, not individual fault

## Argument (optional)

```
/retro                 # retro for the current / most-recent sprint
/retro sprint-3        # a specific sprint
```

---

## Step-by-step

### 1 — Gather the evidence (read-only)

- **Outcomes** — from `docs/ROADMAP.md`: which sprint tasks were delivered `[x]`, which slipped/carried
  over, which were blocked and why. Note `Type: Fix` vs `Feature` mix (lots of fixes = quality signal).
- **Flow** — `git log`/`shortlog` for the sprint window: commit cadence, churn (`git diff --stat`),
  how many tasks needed `/debugger` self-repair or stalled in review.
- **Friction** — the blockers/warnings reviews raised (UX, perf, QA, security, dep), and any pipeline
  stops (DoR failures, RED-gate blocks, tests failing after auto-fix). Recurring blockers are the
  highest-value signal.

### 1b — Sprint-exit checklist (cadence ritual)

Before synthesising, verify the **sprint-exit** checks from *Sprint rituals* in the roadmap — the retro
is where the sprint formally closes:

- [ ] Every task taken into the sprint is DoD-done `[x]` or explicitly carried over (note carry-overs).
- [ ] **Usability** was run on the user-facing features shipped this sprint — heuristic at minimum (`/usability-test`); flag any shipped UI that never got a usability pass.
- [ ] A progress **report** was generated for the review (`/report`).

Any unchecked item becomes an **action item** below (e.g. "run `/usability-test heuristic` on the new
booking flow — shipped without one"). This is how the sprint-level methodology work is *made sure of*:
the retro won't quietly close a sprint that skipped it.

### 2 — Synthesise (don't just list events)

Look for **patterns**, not one-offs: a category of bug that recurred, a DoR field that's always vague, a
review that always blocks for the same reason, an estimate/risk that was repeatedly wrong. Each pattern
is a candidate improvement.

### 3 — Write the retro

Write `docs/retros/<date>-sprint-N.md`:

```markdown
# Retrospective — Sprint N
**Period:** <start> → <end>   ·   Delivered: <n> · Slipped: <n> · Blocked: <n> · Fixes: <n>

## What went well
- <Specific thing that worked — keep doing it>

## What didn't
- <Specific friction, with the evidence: which task / review / commit showed it>

## Patterns & root causes
- <Recurring theme> — likely cause: <…>

## Action items
| # | Action | Type | Owner | Target |
|---|--------|------|-------|--------|
| 1 | <concrete change> | Process / Roadmap task / Skill / Hook / DoR-DoD | <who> | next sprint |

## Kudos
- <What's worth celebrating — momentum matters>
```

Every action item must be **concrete and assignable** — "write better tests" is not an action;
"add a payload-size assertion to the API test template" is. Tag each by **Type** so it routes correctly:
- **Roadmap task** → hand to `/planner` to create it.
- **Process / Skill / Hook / DoR-DoD change** → note the exact file to change (e.g. "tighten the
  `Dependencies` DoR wording", "add a guard for X").

### 4 — Report back

```
✅ Retro written : docs/retros/<date>-sprint-N.md
📊 Sprint        : delivered <n> · slipped <n> · blocked <n>
🔧 Action items  : <n>  (<n> roadmap · <n> process)
➡️  Next          : /planner for the task-shaped actions; apply the process ones directly
```

---

## What retro does NOT do

- Does not change code, tests, schema, or the roadmap — it produces *findings and actions*.
- Does not blame individuals — every item is about the process or the system.
- Does not invent problems to fill the page — a quiet sprint gets a short retro.
- Does not duplicate `/report` — report is outward (what shipped); retro is inward (how to improve).
