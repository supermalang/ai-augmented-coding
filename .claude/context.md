# Project Context

> Fill in this file when you adopt the template. Every pipeline agent reads it at the start
> of each task. Keep it concise — agents read it on every run.
>
> This is the **Tier-1 operational** doc: short facts every agent needs each run. Deep
> architectural detail (system shape, decisions, trust boundaries, hot paths, the standard API
> route pattern) belongs in the optional Tier-2 doc [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md),
> not here — keep the every-run file lean. Product vision lives in `PRODUCT.md`, design language
> in `DESIGN.md`. A fact belongs in exactly one place; don't duplicate across tiers.

---

## Project

**Name:** [Your project name]
**Description:** [One sentence — what it does, for whom]
**Compliance / standards:** [e.g. ISO 27001, GDPR, none]
**Multi-tenant / multi-site:** [yes/no — if yes, describe the isolation key, e.g. `tenantId`]

---

## Tech stack

[List key frameworks and versions — e.g.]
- Next.js 15 (App Router) · React 19 · TypeScript
- Prisma v5 (PostgreSQL)
- Tailwind CSS + shadcn/ui
- Vitest · Playwright

---

## Key commands

```bash
npm run dev          # dev server
npm run build        # production build
npm run lint         # ESLint
npm run test:run     # Vitest single run
npm run test:coverage # Vitest + coverage thresholds
```

---

## Model tiers

Centralized model choice. Each agent envelope (`.claude/agents/*.md`) sets `model:` to one of these
**tier names**, not a concrete model — so re-pointing a tier here re-tiers every agent in it at once.
Set each tier to a concrete model for your runner.

- **reasoning:** [CONFIGURE — strongest model]   # planning, hard coding, debugging, schema design
- **standard:**  [CONFIGURE — mid model]          # reviewers (security / perf / qa / ux / dep), pr-reviewer, test-writer, setup
- **fast:**      [CONFIGURE — cheap/fast model]    # read-only reporters, trace/template work (docs, report, diagram, locate, commit, code-map, visual-*)
- **Principle:** match the model to **reasoning difficulty and the compounding cost of error — NOT to
  pipeline phase.** Execution (`coder`/`debugger`/`schema-agent`) is high-reasoning; do **not**
  under-power it. Reviewers sit at `standard`; read-only reporters and template-fill at `fast`.

> **Resolution.** The tier name in an agent's `model:` is resolved to the concrete model above. Keep
> the mapping here as the single source of truth. Per-agent overrides (a concrete model on one
> envelope) are possible but should be **justified by measured cost/latency**, not guessed — don't
> micro-tune beyond these three tiers. Suggested defaults: `reasoning → opus`, `standard → sonnet`,
> `fast → haiku`.

---

## Dates & timestamps

One format everywhere, always from the **system clock** — never guessed by the agent (a model's idea
of "today" is unreliable).

- **Format:** ISO 8601 UTC datetime — `YYYY-MM-DDThh:mm:ssZ` (e.g. `2026-06-27T14:32:05Z`).
- **Get it from:** `date -u +%Y-%m-%dT%H:%M:%SZ` (run it; do not type a literal date).
- **Filenames** stay date-only: `YYYY-MM-DD` prefix (e.g. `docs/reports/2026-06-27-sprint-3.md`).
- **Duration tracking:** `/start-task` writes a **start timestamp** as line 3 of `.current-task`;
  `/pr-reviewer` records **Started**, **Delivered**, and the **Cycle time** (Delivered − Started) in the
  task's Delivery block. That pair is what lets you measure how long a task actually took.
- Planning dates (`Write date`, `Planned date`) may stay date-only (`YYYY-MM-DD`) — they're estimates,
  not measurements.

---

## Sprint configuration

How work is sized and how much fits in a sprint. Capacity is by *velocity* (points delivered), not a
fixed task count.

- **Sprint length (timebox):** [CONFIGURE — e.g. 2 weeks]
- **Capacity:** estimate-weighted velocity — plan a sprint to ≈ the story points delivered last sprint. No fixed task count.
- **Estimation scale:** story points (Fibonacci 1–13); points measure **size, not hours**.

---

## Version control & forge

How `/pr-reviewer` pushes and opens the PR/MR. Keep the tool name out of the agents — they read this.

- **Forge:** [`github` | `gitlab`]
- **PR target branch:** [CONFIGURE — `develop`]   # the integration branch `/ship-task` opens every PR/MR against; the human validates each, then promotes `develop → main`
- **Protected branches:** `develop`, `main` — no direct pushes; PR + all checks green required to merge. (Branch protection is a **platform setting**, not a repo file — see `docs/branch-protection.md`.)
- **Preview URL source:** the per-PR preview deploy — see the **Preview deploy** section below (the CI step posts the URL to the PR). `none` → link the visual report only. *(Surfaced in every PR's* Visual changes *section.)*
- **Open-PR command:** (`<pr-target>` = the PR target branch above)
  - GitHub → `gh pr create --base <pr-target> --title "…" --body "…"`
  - GitLab → `glab mr create --target-branch <pr-target> --title "…" --description "…"`
- **Unattended auth (batch / CI / cron — no interactive login):** set the token in the environment so push + PR work headless.
  - GitHub → `GH_TOKEN` (read automatically by `gh`); the git remote must use a credential helper or token URL for `git push`.
  - GitLab → `GITLAB_TOKEN` (read by `glab`); same for push.
  - **Never commit the token** — env var only (respects `guard-secret-scan`).

---

## Test execution

How the e2e/visual suite runs, and how it scales across machines. The **core is CI-agnostic** — a
portable script defaults to running the whole suite with no CI; a thin per-vendor adapter (in
`ci-adapters/`, one kept per project) only maps shard indices.

- **CI provider:** [CONFIGURE — `github` | `gitlab` | `container` | `none`]
- **Shard count:** [CONFIGURE — `N` | `auto` (by test count) | `1` (no shard)]   *(don't shard under ~2 min serial)*
- **Playwright image:** [CONFIGURE — `mcr.microsoft.com/playwright:vX.Y.Z-jammy`]   *(pinned; used for CI **and** local baseline-blessing so screenshots are byte-identical)*
- **Visual gate mode:** [CONFIGURE — `inline` | `ci`]   *(`inline` = run the visual suite inside `/ship-task`; `ci` = `/ship-task` opens the PR and a required CI check enforces visual)*

**Portable scripts** (`/setup` adds these to `package.json`; default `1/1` = whole suite, no CI):

```jsonc
"test:e2e:ci":    "playwright test --shard=${SHARD_INDEX:-1}/${SHARD_TOTAL:-1} -c visual-review/playwright.visual.config.ts",
"test:e2e:merge": "playwright merge-reports --reporter html ./all-blob-reports"
```

Each shard emits a **blob** report (the visual config sets `blob` under `CI`); `test:e2e:merge`
stitches one HTML report. Baselines carry a per-OS `{platform}` suffix — bless them in the pinned
image (see `docs/visual-testing.md`) so local == CI.

---

## Parallel worktrees (per-worktree ports & test DB)

For **manual** parallel work: the human runs two sessions at once, each in its own git worktree (own
dir, shared `.git`). Two worktrees booting a dev server or a test DB must not fight over the same
port or database name. Derive a per-worktree suffix once and reuse it for both.

- **`WORKTREE_ID`** — a short per-worktree token. Default: the worktree dir basename
  (`basename "$(git rev-parse --show-toplevel)"`), or a short hash of that root. The **main**
  worktree keeps the base values (offset 0) so single-worktree use is **unchanged**; only *linked*
  worktrees take a suffix/offset.
- **[CONFIGURE] — dev-server port:** base `[e.g. 3000]`; per-worktree port = base + a small
  deterministic offset from `WORKTREE_ID` (main worktree → offset 0).
- **[CONFIGURE] — test-DB name:** pattern `[e.g. myapp_test_${WORKTREE_ID}]`; the main worktree uses
  the bare base name.

Keep the scheme deterministic (same worktree → same port/DB) and bounded. A project sets its own base
port and DB-name pattern here; the defaults leave single-worktree runs exactly as they were. The
visual-report server (`.claude/skills/visual-report/open-report.sh`) already follows this convention
for its report port. See [`docs/parallel-work.md`](../docs/parallel-work.md).

---

## Preview deploy

Give each PR a click-and-see-it-work environment, deployed by CI from the PR branch. Feeds the PR
template's *Visual changes* → **Preview** link. Kept behind a **portable interface**: the CI adapter
(`ci-adapters/`) calls the commands below — it never names a vendor. Leave both blank to disable
(the PR's Preview link is then `None`; nothing else changes — the template stays inert).

- **Preview command:** [CONFIGURE — deploy the PR branch to an ephemeral env; must print the preview URL as its last line of stdout]
- **Teardown command:** [CONFIGURE — destroy the preview when the PR closes]
- **Preview URL source:** the CI preview step above (its printed URL is posted back to the PR).

> Merge and visual-bless stay **human** — a preview is for a person to look at and decide; it never
> auto-merges and never blesses baselines.

---

## Autonomy

How much the pipeline runs without permission prompts. **Safety comes from rules + hooks, never from
removing gates** — autonomy only pre-authorizes a *safe surface*; the deny rules and every `guard-*`
hook stay active in every mode.

- **Mode:** [CONFIGURE — `interactive` | `auto`]
  - `interactive` (default) — normal permission prompts; nothing pre-authorized beyond the `allow`
    list in `.claude/settings.json`.
  - `auto` — run headless: set `permissions.defaultMode` in `.claude/settings.json` to `acceptEdits`
    (or your runner's non-prompting mode) **and** rely on the scoped `allow` list. Do this per project;
    it is not committed on by default so the template stays inert.
- **Always-on, every mode:** the `deny` rules (`git push origin main`, `git push -f:*`, `rm -rf:*`, …)
  and all `guard-*` hooks. Autonomy pre-authorizes the safe subset; hooks auto-deny the dangerous
  subset **without prompting**.

**Hard boundaries auto mode must not cross:**
- **Never auto-bless visual baselines** — `guard-visual-update` stays; blessing is a human action at
  the terminal (inspect with `/visual-report` first), out of band.
- **Merge stays gated** — `/ship-task` never merges; auto-merge, if ever enabled, requires at least a
  green-CI gate (default: off).
- **Don't depend on a self-granted "auto" permission mode** — a repo can't grant itself elevated
  modes (version/tier-gated). Base autonomy on `acceptEdits` + the scoped `allow` list, which travels
  with the repo.
- **Portability:** the `guard-*` hooks are the runner-independent safety core; the permission mode +
  `allow` list is the runner adapter (Claude Code `defaultMode`/`allow`, or the Agent SDK's
  `settingSources`/`allowedTools`). Under headless `-p`, a repeated block **aborts** the run — tune
  the `allow` list from the first runs. Keep `allow` patterns **scoped** (e.g. `Bash(npm run:*)`),
  never a blanket `Bash`.

> The `allow` list and hardened `deny` live in `.claude/settings.json`. Editing that permissions block
> is itself a reviewed change (an agent in auto mode is blocked from silently widening its own
> permissions) — apply it with a human present.

---

## Autonomy trigger

How the pipeline *starts*. **Default `manual`** so the template is inert — a project opts into
`schedule`/`event` deliberately. A triggered run invokes `/ship-task open` (batch) with the caps
below; it opens PRs only, **never merges, never blesses baselines**, keeps all guard hooks active, and
appends WP1 run traces so an unattended run is auditable after the fact.

- **Mode:** [CONFIGURE — `manual` | `schedule` | `event`]   # default: manual
- **Condition:** [CONFIGURE — e.g. cron `"0 8 * * 1-5"` | task labeled `ready` | push to `develop`]
- **Max tasks per run:** [CONFIGURE — cap, e.g. `5`]   # bounds an unattended run → `/ship-task open <cap>`
- **Concurrency:** 1   # parallel tasks; keep 1 unless worktrees are added (see docs/parallel-work.md)

The trigger itself is a thin step in the chosen CI adapter (`ci-adapters/`); its guardrails are in
[`docs/autonomy-trigger.md`](../docs/autonomy-trigger.md). Because a headless run can't answer a
prompt, a triggered run that hits repeated blocks **stops and records the reason** (the run-trace stop
reason) rather than hanging.

---

## Self-improvement (hill-climbing)

The pipeline improving *itself*: an analysis agent reads the **run traces** (`### Run trace` blocks)
and `/retro` outputs, finds recurring patterns, and **proposes** harness changes (prompts / skills /
config) as a PR. It **applies nothing and merges nothing** — the human reviews the PR like any other.

**Default `disabled` and there is NO auto-apply mode** — `propose-only` is the ceiling. This is the
one capability that edits the pipeline itself, so the human stays the gate exactly as everywhere else;
[`guard-hill-climb.sh`](../.claude/hooks/guard-hill-climb.sh) makes direct edits to the harness by this
agent **structurally impossible** (it can only write a proposal doc and open a PR).

- **Mode:** disabled            # `disabled` (default) | `propose-only`. There is **no** auto-apply mode.
- **Cadence:** [CONFIGURE — e.g. end of sprint | manual]
- **Min trace volume:** [CONFIGURE — e.g. 20 runs]   # don't analyze thin data — below this, `/hill-climb` no-ops

See [`.claude/skills/hill-climb/SKILL.md`](../.claude/skills/hill-climb/SKILL.md). Depends on the
shipped run traces; while `disabled`, nothing runs and nothing changes.

---

## Absolute rules

> These are non-negotiable constraints enforced throughout the pipeline.
> Add, remove, or reword to match your project.

1. **[RULE NAME]** — [what must always / never happen, and why]
2. **[RULE NAME]** — [what must always / never happen, and why]
3. **Soft delete only** — never call `.delete()` on ORM models; set `deletedAt = new Date()` instead
4. **Audit log is insert-only** — never update or delete rows in the audit table
5. **Never expose secrets** — [field names that must never appear in API responses, e.g. `passwordHash`]

---

## Roles and access

| Role | Description | Access level |
|------|-------------|--------------|
| [ROLE_A] | [description] | [full / read-only / scoped] |
| [ROLE_B] | [description] | [full / read-only / scoped] |

---

## Data isolation

[Describe how data is scoped, e.g.:]
- Every database query must include `where: { tenantId, deletedAt: null }`
- `tenantId` comes from the JWT session, never from the request body

---

## Domain glossary

| Term | Definition |
|------|------------|
| [Term] | [What it means in this project] |
| [Term] | [What it means in this project] |

---

## UI conventions

- **Language:** [e.g. French / English / Arabic]
- **Icon library:** [e.g. lucide-react — no mixing]
- **Component library:** [e.g. shadcn/ui]
- **Status badge classes:** [document exact Tailwind classes per status, e.g. ACTIVE → `bg-green-100 text-green-800`]
- **Toast library:** [e.g. Sonner]

### Brand assets (reporting)

Exact values used by `/report` to brand PDF decks and PowerPoint exports. The *feel* is in `DESIGN.md`.

- **Logo:** [path, e.g. `assets/brand/logo.svg`]
- **Brand colors:** [primary `#......` · accent `#......` · ink/text `#......` · surface `#......`]
- **Deck fonts:** [heading font · body font — names that exist on the render machine or are embedded]
- **Default deck style:** [`classical` | `notebooklm` | `sketch` | `illustrated`]
- **Image generation (for `illustrated` style only):** [provider + model, e.g. `kie.ai` / `nano-banana`] · API key env var: [e.g. `KIE_API_KEY`] — *key lives in env, never committed*

---

## File structure conventions

```
src/app/          # Next.js App Router pages and API routes
src/lib/          # Pure business logic (tested with Vitest)
src/components/   # Shared UI components
prisma/           # Schema and migrations
tests/e2e/        # Playwright specs
```

---

## Generated files & artifacts

**Single source of truth for where agents write generated files** — do not scatter outputs. Three
buckets by lifecycle; agents pick by *what the file is*, not by convenience.

| Bucket | Location | What | Git |
|---|---|---|---|
| **Knowledge / deliverables** | `docs/<category>/` | `docs/discovery/` · `docs/personas/` · `docs/design/` · `docs/reports/*.md` · `docs/retros/` · `docs/usability/` · `docs/story-map.md` · `docs/ARCHITECTURE.md` | **committed** |
| Roadmap archive | `docs/roadmap/archive/sprint-<N>.md` | full blocks of delivered tasks swept out of the live roadmap by `/roadmap-status archive` (lossless; git also holds them) — keeps `ROADMAP.md` proportional to active work | **committed** |
| Non-reproducible images | `docs/reports/assets/<date>/` | `/report` illustrated-style images (can't be regenerated identically) | **committed** |
| Visual review (committed) | `visual-review/` | `specs/` · `baselines/` (blessed `toHaveScreenshot` PNGs — the approval record) · `visual-approvals.json` | **committed** |
| Visual review (generated) | `visual-review/` | `results/` (actual/diff/report) · `uat/` (`/qa-tester` review shots) | ignored |
| **Generated deliverables** | `out/<type>/` | `out/reports/` PDF + PPTX (regenerable from the committed `.md`) | ignored |
| **Throwaway verification** | `.scratch/<purpose>/` | `.scratch/webapp-testing/` · `.scratch/perf-measure/` | ignored |
| Tool-native output | tool defaults | `coverage/` · `test-results/` · `playwright-report/` — leave where the tools write them | ignored |

Rules: a *regenerable* output is gitignored (`out/`, `.scratch/`, tool dirs); only *knowledge* and
*non-reproducible* artifacts are committed. Never stage `.scratch/`, `out/`, or tool-output dirs in a
task commit. New subfolders are fine **within** a bucket; don't invent new top-level output roots.

**Worktree-relative (parallel-safe).** Every *ephemeral / generated* path above — `.current-task`,
`.scratch/**`, `visual-review/results/**`, `out/**`, run traces, any lockfile/marker — must resolve
from the **worktree root** (`git rev-parse --show-toplevel`; hooks use `$CLAUDE_PROJECT_DIR`, which is
that root), never a fixed/absolute repo path. Two parallel worktrees share one `.git` but have their
own working dir; anchoring generated state to the worktree root is what stops them clobbering each
other. *Committed, shared* inputs (`.claude/**`, `docs/**`, `visual-review/baselines/`) are read from
the current worktree already and need no change. See [`docs/parallel-work.md`](../docs/parallel-work.md).

---

## Visual testing

> Opt-in visual baseline review. **Disabled by default** — while `enabled: false` (or this block is
> absent), no pipeline agent changes behaviour (Tier 0). Enable and scaffold with `/visual-setup`;
> read approval state with `/visual-review`. Runs **in-project — no container**; everything lives
> under one `visual-review/` folder. Determinism: baseline filenames carry a per-OS `{platform}`
> suffix, so capture/bless baselines on the **same OS your CI runs on** (local == CI).

- **enabled:** false
- **root:** visual-review/ # single home: specs/ baselines/ (committed) · results/ uat/ (gitignored)
- **base URL:** —          # served app URL screenshots are taken against
- **serve command:** —     # command that serves the base URL (e.g. npm run dev)
- **config:** —            # e.g. visual-review/playwright.visual.config.ts
- **baselines:** —         # e.g. visual-review/baselines/  (committed)
- **CI OS:** —             # the OS the visual job runs on — baselines must be blessed on this OS

---

## Reference formats

[Document any auto-generated reference numbers, e.g.:]
- Record ID format: `{PREFIX}-{YYYY}-{NNNNN}` (e.g. `ORD-2026-00042`)

---

## Key constraints for agents

- [Any architectural constraint agents must respect, e.g. "always paginate — never return unbounded lists"]
- [e.g. "all mutations must call createAuditLog()"]
- [e.g. "CCP-equivalent operations require re-authentication"]
