---
name: visual-report
description: Human-facing run-and-open command for the visual suite. Runs the Tier-1 Playwright visual specs (headless shell, workers=1, NEVER --update-snapshots) and serves the HTML report so the human can inspect the three-way expected/actual/diff view in a browser. In a Dev Container it binds the report server to 0.0.0.0 on a fixed forwarded port and prints the URL instead of failing to launch a browser. The lightweight stand-in for the Tier 3 review app: it shows the diffs; approval stays a manual `--update-snapshots` + commit at the human's own terminal. Inert at Tier 0. Reads approval state via /visual-review; it does not bless baselines (blocked for agents by guard-visual-update).
---

# /visual-report — Run & Open the Visual Diff Report

## Role

The **human's one-command inspection loop** for visual regressions. It replaces the ceremony of
"run the suite, remember the config path, find the report folder, start a server, guess the port"
with a single guided step: run the Tier-1 specs, then serve Playwright's HTML report — whose
per-screenshot **expected / actual / diff** viewer is exactly what people assume needs the Tier 3
review app. With Tier 3 not in use, this skill *is* the review surface; approval remains a deliberate
human action (`--update-snapshots` + commit), never automated.

It runs **in-project — no container of its own** (the app-under-test may still be containerised).
Determinism is inherited from the Tier-1 config: per-OS `{platform}` baselines + a small pixel
tolerance, so **only inspect/bless on the same OS your CI runs on**.

If visual testing is disabled (no `Visual testing` block, or `enabled: false` in
`.claude/context.md`), report "visual testing disabled — nothing to report" and exit clean. Inert at
Tier 0.

## Permissions

✅ CAN read    : `.claude/context.md` · `visual-review/**` · `docs/ROADMAP.md`
✅ CAN run     : the visual suite **without** `--update-snapshots` · the app serve command (via the
                 config's `webServer`) · `playwright show-report` (report server)
✅ CAN write   : only Playwright's own generated output under `visual-review/results/` (gitignored)
❌ CANNOT      : run `--update-snapshots` / `-u` or otherwise re-baseline — that is a human action,
                 enforced by `guard-visual-update`
❌ CANNOT      : write application source, specs, baselines, or `visual-approvals.json`
❌ CANNOT      : open or gate a PR — approval-state reporting is `/visual-review`

## Argument (optional)

```
/visual-report              # run all visual specs, then serve the report
/visual-report last         # skip the run — just serve the most recent report
/visual-report <substring>  # run only specs whose title/path matches, then serve
```

## Step-by-step

### 1 — Check enablement (idempotency / Tier 0)

Read the `## Visual testing` block in `.claude/context.md`. If absent or `enabled: false` — report
"visual testing disabled — enable with /visual-setup" and **stop**. Otherwise read `config`,
`root`, and `CI OS` from the block; note them for the run and for the OS-parity warning.

### 2 — Run the suite (unless `last`)

Invoke the helper — it wraps the run so the guard can never be tripped (no update flag is ever
passed) and pins the light profile:

```bash
bash .claude/skills/visual-report/open-report.sh run "<optional-substring>"
```

Internally this runs, from the config in the flag:

```bash
npx playwright test -c visual-review/playwright.visual.config.ts --workers=1 [<substring>]
```

`--workers=1` keeps the run lightweight and predictable. A non-zero exit here means screenshots
**differed** — that is expected and is the whole point; do not treat a diff as a hard failure.
Continue to serve the report so the human can see *what* changed.

For `last`, skip this step entirely and go straight to serving the existing
`visual-review/results/report`.

### 3 — Serve & open the report

```bash
bash .claude/skills/visual-report/open-report.sh serve
```

The helper:
- picks the report dir from the config's `outputFolder` (`visual-review/results/report`);
- if it detects a container/remote env (`/.dockerenv`, `$REMOTE_CONTAINERS`, `$CODESPACES`) binds
  `--host 0.0.0.0` so the **host** browser can reach it through the forwarded port, and does **not**
  try to spawn a browser inside the container;
- on a plain local machine, lets `show-report` open the browser directly;
- uses a **fixed port** (default `9323`, override with `VISUAL_REPORT_PORT`) so you can add it to
  `forwardPorts` in `.devcontainer/devcontainer.json` once and reuse it.

Print the exact URL (e.g. `http://localhost:9323`) and tell the user which port to forward if it
isn't already.

### 4 — Report the loop

```
🔎 Visual report served : http://localhost:<port>   (host browser via forwarded port)
📊 In the report        : per-screenshot Expected / Actual / Diff · trace on failures
🖥️  OS parity           : bless only on <CI OS> — baselines carry a per-OS {platform} suffix
✅ Approve a change      : YOU run at your terminal —
                           npx playwright test -c visual-review/playwright.visual.config.ts -u
                           then commit the updated baseline PNGs (+ visual-approvals.json)
🚫 Not automatable       : agents cannot bless (guard-visual-update) — approval is deliberate & human
➡️  Gate state           : /visual-review reads approved / rejected / pending for /pr-reviewer
```

## Auto-open after every run (optional wiring)

If you want the report to open **without** invoking the skill — e.g. every time `/qa-tester` runs
the visual suite — add a `Stop` hook rather than expanding this skill: a one-line
`.claude/hooks/open-visual-report.sh` that calls `open-report.sh serve` when
`visual-review/results/report/index.html` is newer than the last-served marker. Keep it a hook, not
skill logic, so the run path and the view path stay decoupled (single responsibility).

## What /visual-report does NOT do

- Does not re-baseline or run `--update-snapshots` — inspection only; blessing is human + manual.
- Does not write specs, baselines, or `visual-approvals.json` (that's `/visual-setup` scaffolding and
  the human's approval commit).
- Does not compute the merge gate — `/visual-review` owns approved/rejected/pending.
- Does not add Storybook or a review app — Tiers 2/3 stay off; this is the Tier-1 review surface.

## Cross-references

- Enable / scaffold Tier 1: `/visual-setup`
- Approval-state reporter (agent-side gate): `/visual-review`
- Guard that blocks agents from blessing: `.claude/hooks/guard-visual-update.sh`
- Human approval loop + determinism rules: `docs/visual-testing.md`
