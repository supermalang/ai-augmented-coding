---
name: visual-setup
description: Opt-in enabler for visual baseline review. Runs a short interview, verifies (never installs) prerequisites, records a Visual testing flag in .claude/context.md, and scaffolds in-project Playwright config + example route specs under a single visual-review/ folder — no container. Disabled by default — absent the flag, no pipeline agent changes behaviour. Full-route Playwright screenshot baselines; inspect diffs with /visual-report, gate with /visual-review.
---

# /visual-setup — Visual Baseline Review Enabler

## Role

The opt-in front door for **visual regression testing** in the pipeline. It is **disabled by
default** to keep the template stack-agnostic: until this skill writes the `Visual testing` flag to
`.claude/context.md`, nothing else in the pipeline behaves differently (Tier 0).

Like `/setup`, it **defines and scaffolds configuration** — it does **not** install runtimes and does
**not** write application code. Its job is to make deterministic screenshot baselines *possible* with
one guided command, then hand the review loop to a human.

Everything it scaffolds lives under **one `visual-review/` folder**: `specs/` and `baselines/`
(committed), `results/` and `uat/` (gitignored). It runs **in-project — no container**. Determinism
comes from Playwright's per-OS `{platform}` snapshot names plus a small pixel tolerance; the one rule
is **capture/bless baselines on the same OS your CI runs on** (local == CI without Docker).

### Scope — one tier, on purpose

| Tier | Behaviour |
|---|---|
| 0 | disabled (default) — the pipeline is fully inert |
| **1** | Playwright **full-route** screenshot baselines — needs only a served URL |

There is deliberately **no Storybook (component-isolation) or click-through review-app tier** — that
extra machinery isn't worth its maintenance for most projects. Inspect diffs with `/visual-report`
(Playwright's own expected/actual/diff HTML report); approval stays a human `--update-snapshots` +
commit.

## Permissions

✅ CAN read    : all project files · manifests · `.claude/context.md` · `docs/ROADMAP.md`
✅ CAN write   : `.claude/context.md` (the `Visual testing` block only) · scaffolded visual-testing
                 files under `visual-review/` (the Playwright config, `specs/*.visual.spec.ts`) ·
                 `docs/visual-testing.md`
✅ CAN run     : read-only detection (`node --version`, `npx playwright --version`, `command -v …`) and
                 `verify-prereqs.sh`
❌ CANNOT      : install Node, browsers, or any dependency — **detect and remediate only**
❌ CANNOT      : write application source, components, or schema
❌ CANNOT      : write `docs/ROADMAP.md` (that's `/planner`) or edit hook scripts / agent envelopes
❌ CANNOT      : run `--update-snapshots` or bless baselines — that is a human action

## Argument (optional)

```
/visual-setup            # detect state, interview, scaffold
```

---

## Step-by-step

### 1 — Detect current state (idempotency)

Read `.claude/context.md` and look for a `## Visual testing` block.

- **If `enabled: true`** → visual testing is already set up. Do **not** duplicate config. Report the
  current paths and offer to re-verify prerequisites. Never re-write existing files without saying so.
- **If absent or `enabled: false`** → this is a fresh enable. Continue.

Also detect, without asking: the package manager (from `package.json` / lockfile), the installed
Playwright version (`npx playwright --version`, if present), and how the app is served (a
`dev`/`start`/`preview` script) — you'll propose these as defaults in the interview.

### 2 — Interview (only the gaps)

Ask in one small batch, proposing detected defaults so the user can just confirm:

- **Served URL + serve command** — the base URL screenshots are taken against (e.g.
  `http://localhost:3000`) and the command that serves it (e.g. a `dev`/`preview` script). Playwright's
  `webServer` runs it in-project. This is the only hard requirement.
- **CI OS** — the operating system the visual job runs on (e.g. `ubuntu-latest`). Baselines carry a
  per-OS `{platform}` suffix, so they must be **blessed on this same OS** — that's what keeps local ==
  CI. Default to the current OS and note the CI must match.

The footprint is fixed: everything lands under **`visual-review/`** (`specs/` + `baselines/` committed;
`results/` + `uat/` gitignored). No baseline-location question — it's `visual-review/baselines/`.

Stop as soon as served URL + serve command + CI OS are known.

### 3 — Verify prerequisites (detect-only, never install)

Run `.claude/skills/visual-setup/verify-prereqs.sh`. It checks `node` and `npx` (no Docker — capture
runs in-project) and, for anything missing, prints a concrete remediation line — then exits non-zero.

- **If it exits non-zero** → relay the missing items + remediation to the user and **stop**. Do not
  attempt any install. The user sets the runtime up themselves and re-runs `/visual-setup`.
- **If it exits zero** → prerequisites are ready; continue.

> Also confirm `@playwright/test` is a dev dependency. If it isn't, tell the user to add it
> (`npm i -D @playwright/test` then `npx playwright install chromium --with-deps --only-shell`) — do
> not add it or run `playwright install` yourself.

### 4 — Scaffold

Copy the templates from `.claude/skills/visual-setup/templates/`, substituting every `{{…}}` marker
(skip any file that already exists — report it instead of overwriting):

| Template | Written to | Substitutions |
|---|---|---|
| `playwright.visual.config.ts` | `visual-review/playwright.visual.config.ts` | `{{BASE_URL}}` · `{{SERVE_COMMAND}}` |
| `example.visual.spec.ts` | `visual-review/specs/example.visual.spec.ts` | — |
| `visual-testing.md` | `docs/visual-testing.md` | — |

The config resolves `specs/`, `baselines/`, and `results/` **relative to itself**, so the whole
footprint stays inside `visual-review/`. No container file is scaffolded.

Run with `npx playwright test -c visual-review/playwright.visual.config.ts` (or the `test:e2e:ci`
script — see `.claude/context.md` → *Test execution*).

### 5 — Write the flag to `.claude/context.md`

Insert or update the `## Visual testing` block (idempotent — replace in place if it exists, never
append a duplicate):

```markdown
## Visual testing

- **enabled:** true
- **root:** visual-review/
- **base URL:** http://localhost:3000
- **serve command:** [CONFIGURE — the project's dev/preview command]
- **config:** visual-review/playwright.visual.config.ts
- **baselines:** visual-review/baselines/
- **CI OS:** ubuntu-latest   # baselines are blessed on this OS (per-OS {platform} suffix)
```

### 6 — Handoff

```
✅ Visual testing enabled — full-route Playwright screenshots, in-project
📁 Home         : visual-review/  (specs/ baselines/ committed · results/ uat/ gitignored)
🌐 Target       : <base URL> via <serve command>
🖥️  CI OS        : <os> — bless baselines on this OS (per-OS {platform} suffix = local == CI)
▶️  First run    : npx playwright test -c visual-review/playwright.visual.config.ts
                  → writes baselines to visual-review/baselines/; commit the PNGs
🔎 Inspect diffs : /visual-report   ·   Gate state: /visual-review
➡️  Next         : add specs per route; approve changes with --update-snapshots (human-only)
```

---

## What /visual-setup does NOT do

- Does not install Node, browsers, or `@playwright/test` — it detects and remediates only.
- Does not run `--update-snapshots` or bless baselines — approving pixels is a human action.
- Does not scaffold Storybook or a review app — full-route screenshots are the whole surface.
- Does not write application source, roadmap tasks, hook scripts, or agent envelopes.
- Does not change any pipeline behaviour when disabled (Tier 0 = fully inert).

## Cross-references

- Run & inspect the diff report: `/visual-report`
- Read approval state (agent-side gate): `/visual-review`
- The review loop + determinism rules: `docs/visual-testing.md` (scaffolded)
- Guard that blocks agents from re-baselining: `.claude/hooks/guard-visual-update.sh`
