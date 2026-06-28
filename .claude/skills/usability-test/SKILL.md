---
name: usability-test
description: Usability testing — the Design-Thinking "Test" and HCD user-involvement loop the pipeline was missing. Three modes — heuristic (Claude evaluates the running app against Nielsen's 10 heuristics via /webapp-testing), plan (writes a real-user test protocol — scenarios, tasks, observations, SUS survey — for a human to run), and synthesize (themes the human's session findings into prioritized improvements that feed /planner). Read-only on code. Run after a feature is built, before calling it done.
---

# /usability-test — Usability Testing & User Feedback

Before starting, read `.claude/context.md` and, if present, `DESIGN.md` (the experience it should
deliver) and the task's acceptance criteria.

## Role

Closes the loop that criteria-based QA can't: **can a real person actually accomplish the goal, and
where do they struggle?** `/qa-tester` checks the acceptance criteria are *met*; usability testing asks
whether the result is *usable* — discoverable, learnable, low-friction. It is the Design-Thinking "Test"
stage and the HCD principle of involving users, made practical for this pipeline.

**Honest boundary:** Claude cannot recruit or be real users. It *can* run a rigorous **heuristic
evaluation** itself, and it *can* prepare the protocol and synthesize the findings — but the real-user
sessions are run by a human. This skill automates the two-thirds it can and structures the third.

## Permissions

✅ CAN read    : the running app (via `/webapp-testing`), `DESIGN.md`, acceptance criteria, `context.md`
✅ CAN write   : `docs/usability/<slug>.md` (heuristic report · test protocol · findings synthesis)
✅ CAN run     : `/webapp-testing` (drive the app, screenshots, DOM, console) — throwaway, read-only
❌ CANNOT      : edit source, tests, or schema — improvements become `/planner` tasks
❌ CANNOT      : claim real-user results from a heuristic pass — label findings by their source

## Argument

```
/usability-test heuristic <route-or-feature>   # Claude evaluates against Nielsen's 10 heuristics
/usability-test plan <feature>                 # write a real-user test protocol for a human to run
/usability-test synthesize <notes-file|paste>  # turn session findings into prioritized improvements
```

---

## Mode 1 — Heuristic evaluation (Claude runs it)

Drive the feature in a browser with `/webapp-testing` and evaluate against **Nielsen's 10 heuristics**:
visibility of system status · match to the real world · user control & freedom · consistency & standards
· error prevention · recognition over recall · flexibility & efficiency · aesthetic & minimalist design ·
help users recover from errors · help & documentation. For each issue: heuristic violated, where
(screenshot/selector), **severity** (0 cosmetic → 4 catastrophe), and a fix direction. This overlaps
`/ux-review` on visuals but focuses on **task flow and friction**, not visual harmony.

## Mode 2 — Plan a real-user test (human runs it)

Write a protocol a non-expert can execute with 3–5 representative users:
- **Goal & hypotheses** — what we're trying to learn, what we fear is confusing.
- **Participant profile** — which persona (from `PRODUCT.md`), recruitment criteria.
- **Tasks** — 3–6 realistic, goal-oriented scenarios ("book a room for next Tuesday"), *not* instructions
  ("click the blue button"). Define success and observe-for-friction points per task.
- **Measures** — task success rate, time-on-task, error count, and a post-test **SUS** (10-item System
  Usability Scale) or a short confidence/satisfaction survey.
- **Logistics** — moderated vs unmoderated, think-aloud prompt, what to record, ethics/consent note.

## Mode 3 — Synthesize findings (Claude themes them)

Take the human's raw session notes and:
- Cluster observations into **themes** (e.g. "users miss the save action").
- Rate each by **severity × frequency** (how many users hit it, how badly).
- Translate the top themes into **concrete improvements**, framed as `/planner` tasks (`Type: Fix` for
  broken flows, `Feature` for missing affordances), each with the evidence ("4/5 users…").

Write all modes to `docs/usability/<slug>.md`, labelling every finding **[heuristic]** or **[user-tested]**
so a heuristic guess is never mistaken for observed behaviour.

## Report back

```
✅ Usability <mode> → docs/usability/<slug>.md
🔎 Findings   : <n>  (top severity: <n>)
➡️  Next       : /planner for the prioritized improvements  (Fix flows first)
```

## What usability-test does NOT do

- Does not pass off a heuristic evaluation as real-user evidence — sources are labelled.
- Does not edit code — findings become roadmap tasks.
- Does not replace `/ux-review` (visual/a11y) or `/qa-tester` (criteria) — it tests *task usability*.
- Does not bless a baseline or capture visual snapshots (that's `/test-writer`'s visual layer).
