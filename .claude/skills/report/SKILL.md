---
name: report
description: Progress-report generator for status/sprint-review meetings. Reads the roadmap, recent git history, and PRODUCT.md, then writes a branded, stakeholder-readable progress report to docs/reports/<date>.md — and can emit it as a modern PDF deck and an editable PowerPoint (.pptx), both from the same source, with zero extra dependencies (Pandoc + headless Chrome, already on the machine). Read-only on code. Run before a standup, sprint review, or steering update.
---

# /report — Progress Report & Deck Generator

Before starting, read `.claude/context.md` for project facts and `DESIGN.md` for the reporting brand
look-and-feel. Pull the exact brand tokens (logo path, palette, fonts) from `.claude/context.md`.

## Role

The **reporting front door** — the communication counterpart to `/planner`. It does not plan or build;
it **synthesises what already happened** into a report a human can take to a meeting. It reads the
roadmap's status, the git history of the period, and the product vision, and produces one branded
markdown report that can then be emitted as a **PDF deck** and an **editable PowerPoint**.

Markdown is the source of truth (committed, diffable). PDF and PPTX are **build artifacts** — generated
from the markdown + the brand theme, never hand-edited, never committed.

## Permissions

✅ CAN read    : `docs/ROADMAP.md`, `PRODUCT.md`, `DESIGN.md`, `.claude/context.md`, `docs/discovery/*`
✅ CAN read    : git history — `git log`, `git shortlog`, `git diff --stat`, `git branch` (read-only)
✅ CAN write   : `docs/reports/<date>-<scope>.md` · the generated deck under `out/reports/` (gitignored)
✅ CAN write   : the report HTML theme + brand reference template under `.claude/reporting/` (one-time)
✅ CAN run     : `pandoc` (pptx/pdf), headless Chrome via the project's Playwright (PDF print)
❌ CANNOT      : write to source, tests, schema, `docs/ROADMAP.md`, or mark tasks done
❌ CANNOT      : invent progress — every claim must trace to the roadmap or git history
❌ CANNOT      : commit generated binaries (PDF/PPTX live in a gitignored output dir)

## Argument (optional)

```
/report                       # Report for the current/most-recent sprint
/report sprint-3              # A specific sprint
/report --since 2026-06-01    # Custom period
/report --emit pdf,pptx       # Also generate the deck files (default: markdown only)
```

---

## Step-by-step

### 1 — Gather the facts (read-only)

1. **Roadmap** — read `docs/ROADMAP.md`: the Global status table, the sprint section in scope, each
   task's status box, completion date, DoD checkboxes, Priority, and Risk.
2. **Git history for the period** — `git log --since=<start> --pretty` and `git shortlog -sn --since`
   for who-did-what; `git diff --stat <start>..HEAD` for scale of change; open branches/PRs for
   in-flight work. Map commits to task IDs via the Conventional-Commit scope where possible.
3. **Framing** — read `PRODUCT.md` for the vision/goal each shipped task advances, so the report ties
   delivery back to outcomes, not just task counts.

Never state a status the roadmap or git history doesn't support. If something is ambiguous (e.g. a
task marked in-progress with no recent commits), flag it as a risk rather than guessing.

### 2 — Synthesise the report (don't dump)

Write `docs/reports/<date>-<scope>.md`. Lead with a one-paragraph executive summary, then the detail —
so it serves both a steering audience (top) and an engineering standup (detail). Structure:

```markdown
---
title: <Project> — <Scope> Progress Report
date: <today>
scope: <sprint / period>
theme: .claude/reporting/brand        # brand tokens applied at emit time
---

# <Project> — Progress Report
**Period:** <start> → <today>   ·   **Sprint:** <N>

## Executive summary
<2–4 sentences: what moved, against the goal, and the headline risk. Outcome language, not task IDs.>

## Done this period
| Task | Outcome (why it mattered) | Shipped |
|---|---|---|
| <ID — title> | <user/business value, from PRODUCT.md> | <date / PR> |

## In progress
| Task | Status | Confidence | Note |
|---|---|---|---|

## Blocked / risks
- <Blocker or risk> — impact, and the ask/decision needed.

## Next up
| Task | Priority | Why now |
|---|---|---|

## Metrics
- Tasks done this period: <n>   ·   In progress: <n>   ·   Blocked: <n>
- Coverage: <from test:coverage if available>   ·   Open PRs: <n>
- Commits: <n> across <n> tasks
```

Keep it honest and tight — a report that hides a slip is worse than no report.

### 3 — (Optional) Emit the deck — only on `--emit`

Both paths are **zero extra dependency** — Pandoc and headless Chrome are already available. Both
produce **editable / vector** output (not images), branded from the project's tokens.

**Editable PowerPoint — Pandoc native pptx writer:**

```bash
pandoc docs/reports/<date>-<scope>.md \
  -o out/reports/<date>-<scope>.pptx \
  --reference-doc=.claude/reporting/brand-reference.pptx
```

`--reference-doc` is the brand master: its slide layouts, fonts, and colors theme the deck while the
content stays editable text/placeholders. (`#` → section slide, `##` → content slide, tables/bullets
map to placeholders.)

**Modern PDF deck — HTML + headless Chrome:**

1. Render the report into the HTML deck theme at `.claude/reporting/deck.html` — a self-contained,
   modern slide layout whose CSS variables are bound to the brand tokens from `.claude/context.md`.
   Use the `artifact-design` skill's principles for the layout so it looks intentional, not templated.
2. Print to PDF with the project's existing Playwright/Chromium (the `webapp-testing` setup):
   `page.pdf({ path: 'out/reports/<date>.pdf', printBackground: true, landscape: true })`.

This yields a vector, real-text PDF — beautiful and not image-based.

### 4 — First-run setup of the brand assets (one time)

If `.claude/reporting/` is missing, scaffold it without any install:

1. **Brand reference template** — generate Pandoc's default and brand it (it's a zip of XML):
   `pandoc -o .claude/reporting/brand-reference.pptx --print-default-data-file reference.pptx`,
   then patch `ppt/theme/theme1.xml` (palette + fonts) and the slide master (logo) to the tokens in
   `.claude/context.md`. No libraries — standard zip tooling.
2. **HTML deck theme** — write `.claude/reporting/deck.html` with brand CSS variables.
3. Ensure `out/` is gitignored (binaries are artifacts, not source).

### 5 — Report back

```
✅ Report written : docs/reports/<date>-<scope>.md
📊 Period         : <start> → <today>  ·  done <n> · in-progress <n> · blocked <n>
🎨 Emitted        : <pdf / pptx / none>  (out/reports/, gitignored)
➡️  Next           : review, then present
```

---

## What report does NOT do

- Does not change the roadmap, mark tasks done, or touch code — it reports, the pipeline delivers.
- Does not invent or inflate progress — every line traces to the roadmap or git history.
- Does not commit PDF/PPTX — those are gitignored build artifacts, regenerated from the markdown.
- Does not install Python or extra libraries — Pandoc (pptx/pdf) and headless Chrome are enough.
- Does not redefine brand values — it reads tokens from `.claude/context.md` and feel from `DESIGN.md`.
```