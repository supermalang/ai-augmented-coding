---
name: hill-climb
description: Self-improvement (hill-climbing) — reads the shipped run traces + retro outputs, finds recurring pipeline patterns, and PROPOSES harness improvements (prompts/skills/config) as a PR of evidence-linked suggestions. Propose-only — it applies nothing and merges nothing; a human reviews the PR. Disabled by default; runs only in propose-only mode above the minimum trace volume. Read-only on the harness.
---

# /hill-climb — Self-improvement (propose-only)

Before starting, read `.claude/context.md` → *Self-improvement (hill-climbing)*.

The pipeline improving *itself*: analyse what the pipeline has been doing (from the **run traces**
already recorded on delivered tasks and the `/retro` outputs) and **propose** concrete harness changes.
The output is a **PR of suggestions with evidence** — never a direct edit.

## The hard boundary — propose-only, no auto-apply

- There is **no auto-apply mode.** `propose-only` is the ceiling. This is the one capability that
  edits the pipeline itself, so the human stays the gate exactly as everywhere else.
- You **may not** edit `.claude/skills/**`, `.claude/agents/**`, `.claude/hooks/**`, `.claude/settings.json`,
  `.claude/context.md`, `CLAUDE.md`, or any prompt/config. [`guard-hill-climb.sh`](../../hooks/guard-hill-climb.sh)
  **blocks** those writes structurally while you run — your only writable output is the proposal doc.
- You **never** merge and **never** bless baselines. The three human gates are unchanged.

## Permissions

✅ CAN read    : `docs/ROADMAP.md` (+ `docs/roadmap/archive/`) run-trace blocks · `docs/retros/*` · `.claude/**` (to reference, not edit) · git history
✅ CAN write   : **only** `docs/improvements/<date>-hill-climb.md` (the proposal)
✅ CAN run     : read-only git · `git switch -c hill-climb/<date>` · `git add`/`commit` the proposal · `git push` · open a PR/MR via the forge in `.claude/context.md`
❌ CANNOT      : edit any skill, agent, hook, prompt, or config (enforced by `guard-hill-climb`)
❌ CANNOT      : merge, promote, or bless baselines · apply any suggested change itself

## Step-by-step

### 0 — Gate (skip cheaply when off or thin)

Run the gate and obey it:

```bash
bash .claude/skills/hill-climb/should-run.sh
```

- `skip: mode=… (disabled)` → **stop, do nothing.** Disabled is the default; there's nothing to report.
- `skip: N traces < min M (thin data)` → **stop.** Don't analyze thin data (respect `Min trace volume`).
- `run: …` → proceed. (Only `Mode: propose-only` above the minimum trace volume reaches here.)

### 1 — Gather the evidence (read-only)

- **Run traces** — the `### Run trace` block on each delivered task (`docs/ROADMAP.md` + `docs/roadmap/archive/`):
  skills invoked, per-review blockers/warnings, debugger retries, stop reasons.
- **Retro outputs** — `docs/retros/*` for patterns already named and any recurring action items.

### 2 — Find patterns (judgment)

Look for recurring, evidence-backed signals — not one-offs:
- a **reviewer that blocked many tasks** → likely a gap in the *upstream* prompt (e.g. security blocks
  often → the coder prompt under-specifies input validation);
- **high debugger retries on an area** → a coder/test-writer prompt or a missing convention;
- a **gate that is a frequent stop reason** → a DoR/DoD or skill-instruction gap;
- a **skill-path shape** that repeats wastefully.

### 3 — Write the proposal (the only write you may do)

Create `docs/improvements/<YYYY-MM-DD>-hill-climb.md` (date from `date -u +%Y-%m-%d`). For **each**
suggestion give a concrete, evidence-linked entry:

```markdown
# Hill-climb proposal — <date>

**Evidence window:** <N run traces · sprint(s) covered>   ·   **Mode:** propose-only (applies nothing)

## Suggestion 1 — <one-line change>
- **Target:** <exact file to change, e.g. .claude/skills/coder/SKILL.md — "Think before coding" step>
- **Change (proposed):** <what to add/reword — as a description or a fenced diff, NOT applied>
- **Why / evidence:** <the traces that motivate it, cited — e.g. "security blocked 3/8 tasks this
  sprint, all missing Zod validation on new routes (tasks 12.1, 12.4, 13.2 run traces)">
- **Expected effect:** <the metric it should move — e.g. "fewer security blockers next sprint">
- **Risk / caveat:** <what could go wrong, or why it might not help>
```

Rules: every suggestion **must cite the traces** that motivated it; no evidence → don't propose it.
Keep it small and high-signal (a few strong suggestions beat a long wishlist). **Describe** the harness
edit — do not make it. If you catch yourself about to edit a skill/agent/config, that's the guard's
job to stop; put it in the proposal instead.

### 4 — Open the PR (the only output)

```bash
git switch -c hill-climb/<date>
git add docs/improvements/<date>-hill-climb.md
git commit -m "docs(hill-climb): propose harness improvements from run traces (<date>)"
git push -u origin hill-climb/<date>
```

Then open a PR/MR against the **PR target branch** (`.claude/context.md` → *Version control & forge*),
body = a summary of the suggestions + "propose-only: applies nothing; review and decide". Never merge.

### 5 — Report back

```
✅ Hill-climb proposal : docs/improvements/<date>-hill-climb.md
🔎 Suggestions          : <n> (each evidence-linked)
🔗 PR                   : <url>   ·   propose-only — nothing applied or merged
➡️  Over to you          : review the PR; apply the ones you accept through the normal pipeline
```

## What hill-climb does NOT do

- Does not edit the harness (skills/agents/hooks/prompts/config) — proposes only; the guard enforces it.
- Does not merge, promote, or bless baselines.
- Does not run when `disabled` (default) or below `Min trace volume`.
- Does not invent suggestions without trace evidence.
