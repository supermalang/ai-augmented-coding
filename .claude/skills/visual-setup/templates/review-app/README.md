# Visual review app (Tier 3)

A thin, dependency-free local web app for approving screenshot baselines by clicking — the
baseline-vs-candidate side-by-side with **Approve / Reject** (the pattern from the reference
screenshot). Node built-ins only; no `npm install`.

## Run (human only)

```bash
# 1. Produce container-rendered candidates first:
docker compose -f docker-compose.visual.yml run --rm visual   # writes test-results/visual/*-actual.png

# 2. Launch the review app and open it:
node <scaffold-path>/server.mjs      # → http://localhost:4444
```

Approve → the candidate PNG is copied over the baseline (**re-baselined**) and a record is written to
`visual-approvals.json`. Reject → a `rejected` record is written, no re-baseline. Both are read by
`/visual-review` and gate the PR via `/pr-reviewer`.

## Why this is allowed when agents are blocked

Re-baselining here is a **file copy in Node**, not a `playwright … --update-snapshots` shell command —
so the `guard-visual-update` hook (which blocks *agents'* Bash update commands) does not apply. And a
**human** runs this app. Same rule, honoured: only a human (or this app they drive) blesses baselines.

## Approval-environment parity

Candidates are read from `test-results/visual/` — the **pinned-container** run's output — so you
approve the exact pixels CI will produce. Never point the app at a local host render, or approved
baselines will re-fail in CI on font/anti-aliasing differences.

## Config (env, optional)

| Var | Default |
|---|---|
| `PORT` | `4444` |
| `VISUAL_BASELINES_DIR` | `tests/visual/__screenshots__` |
| `VISUAL_OUTPUT_DIR` | `test-results/visual` |
| `VISUAL_APPROVALS` | `visual-approvals.json` |

Task association defaults to line 1 of `.current-task`.

## Test

```bash
node <scaffold-path>/test.mjs        # 10 assertions on the approve/reject/find logic
```
