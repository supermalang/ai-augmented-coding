# claude-pipeline-template

A reusable **Claude Code** pipeline that runs a software project the way a team does — as a
**lifecycle**, from understanding the problem to a released, monitored increment — with a chain of
least-privilege agents and shell-enforced gates that **harden as work approaches code**.

You don't memorise 35-odd commands. You move a piece of work through the phases; at each one you run
a couple of skills, and the pipeline enforces what must be true before the work is allowed forward.

> **See the whole thing on one page:** [`docs/LIFECYCLE.md`](docs/LIFECYCLE.md).

---

## The idea in one line

**No code ships without a ready card, on the right branch, reviewed — and nothing consequential
happens without a human at the gate.** Upstream phases (understanding the problem, shaping the
backlog) are *guided* by skills; the moment work touches `src/`, `tests/`, or the schema, **hooks make
the rules non-negotiable** — you can't edit without an active roadmap task, can't commit to `main`,
can't push except through the PR agent, and reviewers literally cannot edit the code they audit. That
gradient — soft upstream, hard at the code boundary — is the core design. Autonomy is bounded by the
same principle: agents run unattended across the safe surface, hooks auto-deny the dangerous subset,
and a human keeps the handful of gates that carry real consequence.

---

## The lifecycle at a glance

| # | Stage | What you do here | Key commands | Enforcement |
|---|---|---|---|---|
| 1 | **Setup** | Adopt the template, define your stack, tiers, CI | `/setup` · `/code-map` · `/visual-setup` | 🔵 Soft |
| 2 | **Definition** | Understand the problem, users, solution shape (BA · Design Thinking · HCD) | `/discovery` · `/design-import` | 🔵 Soft |
| 3 | **Planning** | Shape a ready, estimated, traceable backlog (Agile) | `/story-map` · `/planner` · `/sprint-start` | 🟠 Hard DoR gate |
| 4 | **Execution** | Build, verify, and ship each card to a PR on `develop` | `/ship-task <ID>` · `/ship-task open` | 🟢 Hard, fail-closed |
| 5 | **Release** | Validate PRs, promote `develop → main`, version & tag | *(human validate)* · `/release` | 🟠 Human gates |
| 6 | **Maintenance** | Fix, evolve, keep healthy — incl. urgent hotfixes | `/debugger` · `/hotfix` · `/dep-audit` · `/refactor` | 🟢 Hard |
| ⟳ | **Observe & Improve** | Runtime health + self-improvement (both default-off) | *health gate* · `/hill-climb` | 🟠 Human gates |
| ⟳ | **Governance** | Steer & communicate across all phases | `/report` · `/retro` · `/roadmap-status` · `/diagram` | — |

Phases 3 ⇄ 4 loop every sprint; retro, usability, and self-improvement feedback can re-open earlier phases.

---

## Getting started

**Prerequisites:** [Claude Code](https://claude.com/claude-code) installed, a git repository, and a
**`bash`** shell to run the hooks (on Windows, **Git Bash**). The write-gating guards
(`guard-roadmap-gate`, `guard-bash-write`) are pure-bash and need nothing else; the remaining hooks
also use **`jq`** + standard coreutils — install `jq` so they don't degrade. The included
[dev container](.devcontainer/devcontainer.json) provisions `jq` automatically.

> **Why this matters:** a guard that can't find its tools fails *open* (silently allows). The
> write-gates are written to fail *closed* with builtins only; for the rest, ensure `jq` is on PATH.

**Fastest path from zero to your first agent-built PR:**

1. **Add the template** — copy `.claude/`, `CLAUDE.md`, and `docs/ROADMAP.md` into your repo (details in [Setup](#setup-details)).
2. **Run `/setup`** — detects your stack, interviews for the gaps, and fills the operational config (`.claude/context.md`, the `[CONFIGURE]` blocks in `CLAUDE.md`, `.claude/hooks/stack-profile.sh`, CI, model tiers, PR target). **Nothing works until this is done** — every agent reads `context.md` each run. **No stack yet?** Run `/discovery` first; `/setup` then recommends one from your PRD's constraints and records the choice as an ADR.
3. **Seed one task** — let `/planner` write it (with a story-point estimate) or add it by hand to `docs/ROADMAP.md`.
4. **Ship it** — `/ship-task <ID>` runs tests → code → reviews → PR **into `develop`**, autonomously.
5. **Validate the PR** — the pipeline opens it in the fixed, reviewable shape; you run human UAT, merge to `develop`, and later promote `develop → main`.

> **Tip:** the first time, point it at a tiny task (one field or one endpoint) to watch the whole loop
> run before trusting it with anything big.

---

## The lifecycle in detail

### 1 · Setup — *template adoption*

**Why.** The orchestration is stack-, CI-, and platform-agnostic; the specifics live in config that
every downstream gate reads. Get them right once.

```
/setup           # detect stack (or recommend one), interview, fill context.md + CLAUDE.md + stack-profile.sh + CI + model tiers
/code-map        # generate .claude/code-map.md — the router index /planner & /locate read
/visual-setup    # OPT-IN — scaffold visual baseline review (off by default)
```

**You can:** retarget any stack by editing one file (`stack-profile.sh`); pick your **CI vendor** (a
`ci-adapters/` reference for GitHub / GitLab / container — keep one); set **model tiers**
(`reasoning`/`standard`/`fast` → concrete models) in one place; choose the **PR target branch**
(default `develop`). **Enforcement:** soft.

### 2 · Definition — *business analysis · Design Thinking · HCD*

```
/discovery       # requirements/PRD/HCD interview → PRD + INVEST stories + threat model
/design-import   # OPTIONAL — pull a design into a spec via Google Stitch MCP
```

Turns a fuzzy idea into a `docs/discovery/<slug>.md` PRD; captures personas
(`docs/personas/<slug>.md`); seeds `PRODUCT.md` and `DESIGN.md`. **Enforcement:** soft — discovery's
own DoR requires persona + job-to-be-done before handoff.

### 3 · Planning — *Agile backlog shaping*

```
/story-map       # user journey × release-slice view; reconciles map ↔ roadmap
/planner         # write a roadmap task with full DoR + story-point estimate; challenges vague criteria
/sprint-start    # time-boxed sprint; capacity = estimate-weighted velocity; audits DoR (hard gate)
```

Every task carries a **`Journey:` coordinate** (`/story-map` flags GAPS and ORPHANS) and a
**story-point `Estimate`**. `/planner` **challenges untestable acceptance criteria** — a vague
criterion is a signal to clarify, not something to test around — and validates each task's persona
against `PRODUCT.md`. Dependencies are first-class; `/ship-task open` won't start a task until its
dependencies are delivered. **Enforcement:** hard DoR gate at the Execution boundary.

### 4 · Execution — *build · verify · ship*

**Run — autonomous (recommended):**
```
/ship-task 1.1        # one task — tests → code → reviews → PR into develop, no input between steps
/ship-task open       # batch: every ready task whose dependencies are delivered, priority-ordered
```

`/ship-task` hands control back on exactly three things: a task that isn't DoR-ready, tests
`/debugger` couldn't fix after 2 tries, or a review blocker. Otherwise it runs to an open PR on the
target branch. Each run **records a structured run trace** (skills fired, reviewer blockers, retries,
stop reason) into the task — the substrate `/retro` and `/hill-climb` later read.

| Step | Agent | Runs when |
|------|-------|-----------|
| 0 | Validate | Always — DoR check |
| 1 | Start | Always — branch + `.current-task` |
| 2 | Schema | Schema impact = `Migration` |
| 3 | Test Writer (RED) | Always — tests + axe a11y from criteria; hard-stops if a RED test passes |
| 3b | Locate (scout) | Always — cheap `fast`-tier pass; scopes the change-set |
| 4 | Coder **or** Debugger | `/coder` for a Feature, `/debugger` for a `Type: Fix` |
| 5 | Test Writer (GREEN) | Always — confirms all tests pass |
| 5b | Debugger (self-repair) | If GREEN fails — auto root-cause + fix, up to 2× |
| 6 | Docs | API/schema/UI changed — or modules moved |
| 7 | Commit | Always — lint + Conventional Commit before reviews |
| 8–11b | UX · Performance (review+measure) · QA · Security · Dep-audit | In parallel; any blocker stops the pipeline |
| 12 | PR Reviewer | Always — records estimate/cycle-time/perf + run trace, opens the PR in the fixed shape |

**The PR shape** (filled by `/pr-reviewer`, ordered by what you decide first): summary → ticked
acceptance criteria → visual changes (preview + expected/actual/diff links) → checks & facts
(estimate, cycle time, perf) → risk flags (schema/auth/deps) → diff last. **Enforcement:** hard,
fail-closed — no edit to gated paths without an active task on the correct branch; no commit to
`main`; only `/pr-reviewer` pushes; reviewers have no edit tools; agents **can never bless their own
visual baselines** (`guard-visual-update`).

### 5 · Release — *validate · promote · version*

**Why.** Execution ends at a PR on `develop`. Release turns validated work into a versioned increment.

```
# You validate each PR on develop (green checks + preview + criteria) and merge, one by one.
# When a batch is good, you promote develop → main (both branches protected).
/release         # derive semver bump from conventional commits, bump version, update CHANGELOG, draft notes, tag
```

`/release` derives the version from Conventional Commits (leaning on `guard-commit-message`).
**Publishing is a separate, `[CONFIGURE]`, default-off step** — unset, it computes the version, writes
the changelog/notes, tags locally, and publishes nothing. **Enforcement:** human gates on merge,
promotion, and publish.

### 6 · Maintenance — *run & evolve*

```
/debugger        # a Type: Fix card — reproduce, root-cause, minimal fix (regression test first)
/hotfix          # urgent production incident — fast-lane (see below)
/dep-audit       # SCA scan: vulnerable / outdated deps + risky licenses (OWASP A06)
/refactor        # behaviour-preserving cleanup, guarded by green tests
/performance measure # bundle / Web Vitals / query EXPLAIN vs budget
/roadmap-status  # progress; mark done; archive delivered blocks
```

**`/hotfix`** is the emergency lane: it branches from the **production branch** (not `develop`),
reproduces the bug as a **failing regression test first**, applies the minimal fix, runs the relevant
guards + a focused review, and opens a PR into production — **never auto-merging**. Fast means skipping
*ceremony* (sprint/DoR/estimation), never *safety* (regression test, guards, human merge gate). After
merge it back-merges production → `develop` and backfills the incident into a roadmap task + run
trace. **Enforcement:** hard — a hotfix has no guard exemptions; it *adds* the test requirement
(`guard-hotfix-test`).

### ⟳ Observe & Improve — *both default-off*

```
# Observability (runtime) — default OFF, inert until enabled:
#   emit errors/metrics + a post-deploy health gate with auto-rollback (docs/health-gate.md).
#   The prerequisite for any future auto-deploy; ships as a disabled spec.
/hill-climb      # self-improvement — reads run traces + retro, PROPOSES harness improvements as a PR
```

**`/hill-climb`** is the self-improvement loop: it reads accumulated run traces and `/retro` output,
finds recurring pipeline patterns, and opens a **PR of evidence-linked suggestions** to prompts/skills/
config. It is **disabled by default** and **propose-only** — there is no auto-apply mode, and
`guard-hill-climb` makes direct edits to the harness structurally impossible; its only output is a
proposal PR you review. **Observability** is likewise default-off and fully inert until a project
wires its backend.

### ⟳ Governance, Communication & Continuous Improvement

```
/report          # branded progress report + PDF/PPTX deck
/retro           # end-of-sprint retro → velocity, cycle-time-per-point, carryover, perf-blocker trend → action items feed /planner
/usability-test  # heuristic eval + real-user protocol + findings synthesis (HCD)
/diagram         # Mermaid ERD / architecture / sequence / flow, embedded in docs
/roadmap-status  # status, done-marking, archiving
```

---

## The two enforcement layers

- **Agents** ([`.claude/agents/`](.claude/agents/)) — the *envelope*: least-privilege tools + a
  right-sized **model tier** per role. Report-only reviewers have **no Edit/Write**; `/locate`,
  `/visual-review`, `/code-map` are read-only; only `/pr-reviewer` (and `/hotfix`/`/release` at their
  gates) can open PRs. Tiers are `reasoning` (hard builders/auditors — planner, coder, debugger,
  schema), `standard` (reviewers), `fast` (read-only routing/reporters), mapped to concrete models in
  `context.md → Model tiers` so you swap models in one place. `/ship-task` dispatches every step
  through these, so least privilege is a hard boundary.
- **Hooks** ([`.claude/settings.json`](.claude/settings.json) + [`stack-profile.sh`](.claude/hooks/stack-profile.sh))
  — the *backstop*: **15 guards** (roadmap gate, branch, no-commit-to-main, Conventional Commits,
  destructive-DB, shell-write, generated-files, test-files, audit-log, expose-hash, soft-delete,
  secret-scan, visual-update, **hotfix-test**, **hill-climb**) + **4 reminders/warnings** (code-map,
  docker-rebuild, docs-generate, **worktree-overlap**). Every stack-specific pattern lives in
  `stack-profile.sh` — retarget by editing one file, never the hook scripts. Guards fire in **every**
  mode, including auto-mode — they're what make unattended runs safe.

---

## Running unattended & autonomy

For batch / CI / cron with no interactive login:

- **`/ship-task open`** drains the ready backlog autonomously to PRs on `develop`.
- **Auto-mode** pre-authorizes a safe surface (an allow-list + `dontAsk`/`acceptEdits` in
  `context.md → Autonomy`) so agents don't stop to ask permission; the guards still auto-deny the
  dangerous subset. **Deny rules + guards are always on.**
- **Event-driven trigger** (`context.md → Autonomy trigger`, default **manual**) can fire
  `/ship-task open` on a schedule/event, bounded by `Max tasks per run` and `Concurrency`.
- Unattended push/PR work headless once a forge token is in the environment (`GH_TOKEN` / `GITLAB_TOKEN`;
  set the forge in `context.md`). **Never commit the token.**

The pipeline ships *up to the PR, not through merge*: merge, visual-bless, `develop → main` promotion,
publish, and applying a hill-climb proposal all stay **human**. A task shipped-but-unmerged doesn't
satisfy dependents until you merge.

---

## Parallel work (manual)

Run several tasks at once by hand using **git worktrees** (one directory per branch — see
[`docs/parallel-work.md`](docs/parallel-work.md)). Branch/staged-diff guards are isolated per worktree
automatically; ephemeral state resolves from the worktree root, and a per-worktree port/DB convention
avoids collisions. `warn-worktree-overlap` **warns** (never blocks) if a sibling worktree touches the
same file. The durable rule: parallel worktrees only on tasks with **disjoint files** (INVEST
independence). Automatic pipeline parallelism stays off (`Concurrency: 1`).

---

## CI — vendor-agnostic & sharded

The heavy browser suite runs in CI, sharded across machines via a portable `SHARD_INDEX/SHARD_TOTAL`
contract; a pinned Playwright image keeps local-vs-CI screenshot parity. `ci-adapters/` ships
reference workflows for **GitHub** (matrix), **GitLab** (`parallel`), and **container** — keep the one
your project uses; the core names no vendor. Per-PR **preview deploys** and the visual gate are
`[CONFIGURE]` (default off/inline).

---

## Project knowledge — two tiers

- **Tier 1 — operational (read every run):** `CLAUDE.md`, `.claude/context.md`, `docs/ROADMAP.md`.
- **Tier 2 — knowledge (read when relevant):** standing entrypoints indexing per-feature docs.

| Tier-2 doc | Holds | Read by |
|---|---|---|
| `PRODUCT.md` | Vision, users, non-goals; indexes discovery/ + personas/ | `/discovery`, `/planner` |
| `DESIGN.md` | Design language; indexes design/ | `/design-import`, `/ux-review` |
| `docs/TESTING.md` | Testing philosophy (Testing Trophy) + critical-journeys + a11y | `/test-writer`, `/qa-tester`, `/coder`, visual skills |
| `docs/ARCHITECTURE.md` | System shape, decisions, deep specs | `/coder`, `/schema-agent`, `/performance`, `/security-audit` |
| `docs/LIFECYCLE.md` · `docs/health-gate.md` · `docs/parallel-work.md` · `docs/branch-protection.md` · `docs/pr-template.md` · `docs/autonomy-trigger.md` | Lifecycle, health gate spec, worktree/branch/PR/trigger setup | humans + relevant skills |

**The one rule against drift:** a fact lives in exactly one tier.

---

## Setup details

### 1. Copy the template

```bash
# Option A — use as a GitHub/GitLab template repository (recommended).
# Option B — copy into an existing project:
git clone https://[your-forge]/claude-pipeline-template temp-template
cp -r temp-template/.claude your-project/
cp -r temp-template/ci-adapters your-project/     # keep the adapter for your CI
cp temp-template/CLAUDE.md your-project/
cp temp-template/docs/ROADMAP.md your-project/docs/
cp temp-template/PRODUCT.md temp-template/DESIGN.md your-project/          # optional Tier-2
cp temp-template/docs/ARCHITECTURE.md temp-template/docs/TESTING.md your-project/docs/
cp temp-template/.gitignore your-project/   # merge, don't overwrite
rm -rf temp-template
```

### 2. Run `/setup` (or configure by hand)

`/setup` fills: `.claude/context.md` (per-project config incl. **Model tiers · Test execution · PR
target · Autonomy · Observability · Release** blocks), the `CLAUDE.md` `[CONFIGURE]` blocks,
`.claude/hooks/stack-profile.sh`, the chosen `ci-adapters/` workflow, and `docs/ROADMAP.md` seed.

---

## What to customise per project

| File | What to change |
|------|---------------|
| `.claude/context.md` | Everything — per-project config, incl. model tiers, CI/test-execution, PR target, autonomy, observability, release |
| `CLAUDE.md` | `[CONFIGURE]` sections — stack, commands, absolute rules |
| `.claude/hooks/stack-profile.sh` | All stack-bound hook patterns — one file |
| `ci-adapters/<vendor>/` | Keep the adapter for your CI; delete the rest |
| `docs/ROADMAP.md` | Domain names in the global status table |
| `PRODUCT.md` · `DESIGN.md` · `docs/ARCHITECTURE.md` | **Optional** Tier-2 docs — skills create/update on demand |

---

## Adapting to another stack

Ships configured for **React / Next.js · Prisma · TypeScript · Vitest**, but the orchestration is
language-agnostic. Retargeting edits **two files** — `.claude/context.md` (commands, ORM, tiers) and
`.claude/hooks/stack-profile.sh` (guard patterns; worked overrides for **Laravel**, **Django**,
**FastAPI** included). Any variable left unset keeps the Prisma/Next default. Swap the JS-specific
reference skills and your `ci-adapters/` workflow; the orchestration and review skills carry over
unchanged.

---

## File structure

```
.claude/
  context.md          ← per-project config (read by all agents): stack, tiers, CI, PR target, autonomy, observability, release
  code-map.md         ← generated router index; read by /planner, /locate
  settings.json       ← hook configuration + auto-mode permissions
  hooks/              ← 15 guards + 4 reminders/warnings
    stack-profile.sh  ← all stack-specific patterns (retarget here)
  agents/             ← 24 agent definitions (tool scope + model tier per role)
  skills/             ← 35 skills — setup, discovery, design-import, story-map, planner, sprint-start,
                        start-task, ship-task, locate, code-map, schema-agent, coder, debugger,
                        test-writer, ux-review, performance, qa-tester, security-audit, dep-audit,
                        refactor, webapp-testing, docs, diagram, commit, pr-reviewer, release, hotfix,
                        roadmap-status, report, retro, usability-test, hill-climb,
                        visual-setup, visual-report, visual-review
ci-adapters/          ← portable CI: github/ · gitlab/ · container/ (keep one)
docs/
  ROADMAP.md          ← DoR / DoD / task template (+ Estimate) + sprint planning   (Tier-1)
  LIFECYCLE.md        ← the phase view of the pipeline
  TESTING.md          ← testing philosophy + critical journeys + a11y   (Tier-2)
  ARCHITECTURE.md     ← system shape, decisions, deep specs             (Tier-2)
  health-gate.md      ← observability health-gate + rollback spec (default off)
  autonomy-trigger.md · branch-protection.md · parallel-work.md · pr-template.md
  discovery/ · personas/ · design/ · roadmap/
CLAUDE.md             ← project instructions for Claude Code            (Tier-1)
PRODUCT.md · DESIGN.md ← optional Tier-2 entrypoints
.gitignore            ← includes .current-task, .scratch/, visual-review/results/
```