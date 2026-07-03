---
name: visual-setup
description: Opt-in enabler for visual baseline review. Runs a short interview, verifies (never installs) prerequisites, records a Visual testing flag in .claude/context.md, and scaffolds a pinned Playwright container + config + example route specs. Disabled by default — absent the flag, no pipeline agent changes behaviour. Tier 1 = Playwright full-route screenshots (default); Tier 2 adds Storybook; Tier 3 adds a local review app.
---

# /visual-setup — Visual Baseline Review Enabler

## Role

The opt-in front door for **visual regression testing** in the pipeline. It is **disabled by
default** to keep the template stack-agnostic: until this skill writes the `Visual testing` flag to
`.claude/context.md`, nothing else in the pipeline behaves differently (Tier 0).

Like `/setup`, it **defines and scaffolds configuration** — it does **not** install runtimes and does
**not** write application code. Its job is to make deterministic screenshot baselines *possible* with
one guided command, then hand the review loop to a human.

### Tiers (chosen in the interview)

| Tier | Adds | Stack-agnostic | Delivered by |
|---|---|---|---|
| 0 | (disabled) | — | default |
| **1** | Playwright full-route screenshots — needs only a served URL | ✅ high | **this skill** |
| 2 | + Storybook component-isolation stories | ⚠️ framework-coupled | `/visual-setup` (VBR-4) |
| 3 | + a local clickable Approve/Reject review app | Node app | `/visual-setup` (VBR-5) |

**This skill fully implements Tier 1.** Tiers 2 and 3 are added by later tasks; if the user picks one
before it's available, record the intent, scaffold Tier 1, and say the higher tier is coming.

## Permissions

✅ CAN read    : all project files · manifests · `.claude/context.md` · `docs/ROADMAP.md`
✅ CAN write   : `.claude/context.md` (the `Visual testing` block only) · scaffolded visual-testing
                 files at the project root (`docker-compose.visual.yml`, the visual Playwright config,
                 an example `*.visual.spec.ts`, `docs/visual-testing.md`)
✅ CAN run     : read-only detection (`node --version`, `npx playwright --version`, `command -v …`) and
                 `verify-prereqs.sh`
❌ CANNOT      : install Node, browsers, Docker, or any dependency — **detect and remediate only**
❌ CANNOT      : write application source, components, or schema
❌ CANNOT      : write `docs/ROADMAP.md` (that's `/planner`) or edit hook scripts / agent envelopes
❌ CANNOT      : run `--update-snapshots` or bless baselines — that is a human action

## Argument (optional)

```
/visual-setup            # detect state, interview, scaffold
/visual-setup 1          # start from a tier hint (1 | 2 | 3)
```

---

## Step-by-step

### 1 — Detect current state (idempotency)

Read `.claude/context.md` and look for a `## Visual testing` block.

- **If `enabled: true`** → visual testing is already set up. Do **not** duplicate config. Report the
  current tier + paths and offer to **change tier** (e.g. 1 → 2) or re-verify prerequisites. Only
  scaffold the delta for a tier change; never re-write existing files without saying so.
- **If absent or `enabled: false`** → this is a fresh enable. Continue.

Also detect, without asking: the UI framework and package manager (from `package.json` / lockfile),
the installed Playwright version (`npx playwright --version`, if present), and how the app is served
(a `dev`/`start`/`preview` script) — you'll propose these as defaults in the interview.

### 2 — Interview (only the gaps)

Ask in one small batch, proposing detected defaults so the user can just confirm:

- **Tier** — 1 (default), 2, or 3. If they pick 2/3 and it isn't implemented yet, record the intent
  and proceed with Tier 1, noting the upgrade is coming.
- **Served URL + serve command** — the base URL screenshots are taken against (e.g.
  `http://localhost:3000`) and the command that serves it (e.g. `npm run dev`, or a static
  `preview`). Tier 1 needs a real URL; this is the only hard requirement.
- **Pinned image tag** — default to the tag matching the detected Playwright version
  (`mcr.microsoft.com/playwright:v<version>-noble`). Pinning is mandatory; never `:latest`.
- **Worker/resource budget** — vCPU allotted to the container (default 2). `PW_WORKERS` = that number;
  memory ≈ 1.5 GB × workers. Explain the container-core gotcha briefly if asked.
- **Baseline location** — default `tests/visual` (baselines land in `tests/visual/__screenshots__/`).
  Confirm or override. Baselines are **committed** (the approval record); run artifacts go to
  `test-results/visual/` and the report to `playwright-report/`, both already gitignored — never
  commit those.

Stop as soon as tier + served URL + pinned tag + worker budget are known.

### 3 — Verify prerequisites (detect-only, never install)

Run `.claude/skills/visual-setup/verify-prereqs.sh`. It checks `node`, `npx`, and `docker` (the Tier 1
default set) and, for anything missing, prints a concrete remediation line — then exits non-zero.

- **If it exits non-zero** → relay the missing items + remediation to the user and **stop**. Do not
  attempt any install. The user sets the runtime up themselves and re-runs `/visual-setup`.
- **If it exits zero** → prerequisites are ready; continue.

> Also confirm `@playwright/test` is a dev dependency. If it isn't, tell the user to add it
> (`npm i -D @playwright/test`) — do not add it or run `playwright install` yourself.

### 4 — Scaffold Tier 1

Copy the templates from `.claude/skills/visual-setup/templates/`, substituting every `{{…}}` marker,
to the project root (skip any file that already exists — report it instead of overwriting):

| Template | Written to | Substitutions |
|---|---|---|
| `docker-compose.visual.yml` | `docker-compose.visual.yml` | `{{PLAYWRIGHT_TAG}}` · `{{PW_WORKERS}}` · `{{CPUS}}` · `{{MEMORY}}` · `{{BASE_URL}}` · `{{VISUAL_CONFIG}}` |
| `playwright.visual.config.ts` | `playwright.visual.config.ts` | `{{VISUAL_TEST_DIR}}` · `{{BASE_URL}}` · `{{SERVE_COMMAND}}` |
| `example.visual.spec.ts` | `<VISUAL_TEST_DIR>/example.visual.spec.ts` | — |
| `visual-testing.md` | `docs/visual-testing.md` | `{{VISUAL_CONFIG}}` |

Defaults: `VISUAL_TEST_DIR = tests/visual`, `VISUAL_CONFIG = playwright.visual.config.ts`,
`PW_WORKERS = CPUS` (both default 2), `MEMORY = 3g`. Keep `PW_WORKERS` and `CPUS` equal.

### 5 — Write the flag to `.claude/context.md`

Insert or update the `## Visual testing` block (idempotent — replace in place if it exists, never
append a duplicate):

```markdown
## Visual testing

- **enabled:** true
- **tier:** 1
- **pinned image:** mcr.microsoft.com/playwright:v<version>-noble
- **base URL:** http://localhost:3000
- **serve command:** npm run dev
- **config:** playwright.visual.config.ts
- **baselines:** tests/visual/__screenshots__/
- **workers (PW_WORKERS):** 2   # sized to container cpus: 2 · mem 3g
```

### 6 — Handoff

```
✅ Visual testing enabled — Tier 1 (Playwright full-route)
🐳 Pinned image : mcr.microsoft.com/playwright:v<version>-noble  (local == CI)
🌐 Target       : <base URL> via <serve command>
🧵 Workers      : PW_WORKERS=<n>  (cpus <n> · mem <mem>)
📁 Baselines    : tests/visual/__screenshots__/
▶️  First run    : docker compose -f docker-compose.visual.yml run --rm visual
                  → writes baselines; review with `npx playwright show-report`, commit the PNGs
➡️  Next         : add specs per route; approve changes with --update-snapshots (human-only)
```

---

## What /visual-setup does NOT do

- Does not install Node, browsers, Docker, or `@playwright/test` — it detects and remediates only.
- Does not run `--update-snapshots` or bless baselines — approving pixels is a human action.
- Does not write application source, roadmap tasks, hook scripts, or agent envelopes.
- Does not change any pipeline behaviour when disabled (Tier 0 = fully inert).

## Cross-references

- Read approval state (agent-side): `/visual-review`
- The review loop + determinism rules: `docs/visual-testing.md` (scaffolded)
- Guard that blocks agents from re-baselining: `.claude/hooks/guard-visual-update.sh`
