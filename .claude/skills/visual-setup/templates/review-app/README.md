# Visual review app (Tier 3)

A thin, dependency-free local web app for approving screenshot baselines by clicking — the
baseline-vs-candidate side-by-side with **Approve / Reject** (the pattern from the reference
screenshot). Node built-ins only; no `npm install`. Lives at `visual-review/review-app/`.

## Run (human only)

```bash
# 1. Produce candidates first (in-project — no container):
npx playwright test -c visual-review/playwright.visual.config.ts   # writes visual-review/results/output/*-actual.png

# 2. Launch the review app and open it:
node visual-review/review-app/server.mjs      # → http://localhost:4444
```

Approve → the candidate PNG is copied over the baseline (**re-baselined**) and a record is written to
`visual-review/visual-approvals.json`. Reject → a `rejected` record is written, no re-baseline. Both are
read by `/visual-review` and gate the PR via `/pr-reviewer`.

## Why this is allowed when agents are blocked

Re-baselining here is a **file copy in Node**, not a `playwright … --update-snapshots` shell command —
so the `guard-visual-update` hook (which blocks *agents'* Bash update commands) does not apply. And a
**human** runs this app. Same rule, honoured: only a human (or this app they drive) blesses baselines.

## Approval-environment parity

Candidates are read from `visual-review/results/output/` — the run's output. Approve on the **same OS
your CI runs on** (baselines carry a per-OS `{platform}` suffix), or approved baselines may re-fail in
CI on font/anti-aliasing differences.

## Config (env, optional)

| Var | Default |
|---|---|
| `PORT` | `4444` |
| `VISUAL_BASELINES_DIR` | `visual-review/baselines` |
| `VISUAL_OUTPUT_DIR` | `visual-review/results/output` |
| `VISUAL_APPROVALS` | `visual-review/visual-approvals.json` |

Task association defaults to line 1 of `.current-task`.

## Test

```bash
node visual-review/review-app/test.mjs        # assertions on the approve/reject/find logic
```
