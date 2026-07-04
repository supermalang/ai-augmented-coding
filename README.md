# claude-pipeline-template

A reusable **Claude Code** pipeline that runs a software project the way a team does — as a
**lifecycle**, from understanding the problem to a shipped PR — with a chain of least-privilege
agents and shell-enforced gates that **harden as work approaches code**.

You don't memorise 30-odd commands. You move a piece of work through five phases; at each one you run
a couple of skills, and the pipeline enforces what must be true before the work is allowed forward.

> **See the whole thing on one page:** [`docs/LIFECYCLE.md`](docs/LIFECYCLE.md) · or the
> [visual lifecycle](https://claude.ai/code/artifact/cdb2f569-94a8-4709-931b-fafd62876bd8).

---

## The idea in one line

**No code ships without a ready card, on the right branch, reviewed.** Upstream phases (understanding
the problem, shaping the backlog) are *guided* by skills; the moment work touches `src/`, `tests/`, or
the schema, **hooks make the rules non-negotiable** — you can't edit without an active roadmap task,
can't commit to `main`, can't push except through the PR agent, and reviewers literally cannot edit the
code they audit. That gradient — soft upstream, hard at the code boundary — is the core design.

---

## The lifecycle at a glance

| # | Stage | What you do here | Key commands | Enforcement |
|---|---|---|---|---|
| 1 | **Setup** | Adopt the template, define your stack | `/setup` · `/code-map` · `/visual-setup` | 🔵 Soft |
| 2 | **Definition** | Understand the problem, users, solution shape (BA · Design Thinking · HCD) | `/discovery` · `/design-import` | 🔵 Soft |
| 3 | **Planning** | Shape a ready, traceable backlog (Agile) | `/story-map` · `/planner` · `/sprint-start` | 🟠 Hard DoR gate |
| 4 | **Execution** | Build, verify, and ship each card | `/ship-task <ID>` · `/ship-task open` | 🟢 Hard, fail-closed |
| 5 | **Maintenance** | Fix, evolve, keep healthy | `/debugger` · `/dep-audit` · `/refactor` | 🟢 Hard |
| ⟳ | **Governance** | Steer & communicate across all phases | `/report` · `/retro` · `/roadmap-status` · `/diagram` | — |

Phases 3 ⇄ 4 loop every sprint; retro and usability feedback can re-open Definition.

---

## Getting started

**Prerequisites:** [Claude Code](https://claude.com/claude-code) installed, a git repository, and a
**`bash`** shell to run the hooks (on Windows, **Git Bash**). The two write-gating guards
(`guard-roadmap-gate`, `guard-bash-write`) are pure-bash and need nothing else; the remaining hooks
also use **`jq`** + standard coreutils — install `jq` so they don't degrade. The included
[dev container](.devcontainer/devcontainer.json) provisions `jq` automatically.

> **Why this matters:** a guard that can't find its tools fails *open* (silently allows). The
> write-gates are written to fail *closed* with builtins only; for the rest, ensure `jq` is on PATH.

**Fastest path from zero to your first agent-built PR:**

1. **Add the template** — copy `.claude/`, `CLAUDE.md`, and `docs/ROADMAP.md` into your repo (details in [Setup](#setup-details) below).
2. **Run `/setup`** — detects your stack, interviews for the gaps, and fills the operational config (`.claude/context.md`, the `[CONFIGURE]` blocks in `CLAUDE.md`, `.claude/hooks/stack-profile.sh`, `package.json` scripts, coverage). **Nothing works until this is done** — every agent reads `context.md` each run.
3. **Seed one task** — let `/planner` write it (or add it by hand to `docs/ROADMAP.md`).
4. **Ship it** — `/ship-task <ID>` runs tests → code → reviews → PR autonomously.
5. **Review the PR** — the pipeline opens it; you run human UAT and merge.

> **Tip:** the first time, point it at a tiny task (one field or one endpoint) to watch the whole loop
> run before trusting it with anything big.

---

## The lifecycle in detail

Each stage below: **why** it exists, **what to run**, and **what you can do** there.

### 1 · Setup — *template adoption*

**Why.** The orchestration is stack-agnostic; the stack-specific facts live in config that every
downstream gate reads. Get them right once.

**Run.**
```
/setup           # detect stack, interview, fill .claude/context.md + CLAUDE.md + stack-profile.sh + scripts
/code-map        # generate .claude/code-map.md — the router index /planner & /locate read
/visual-setup    # OPT-IN — scaffold visual baseline review (off by default)
```

**You can:** retarget any stack by editing one file (`stack-profile.sh`, examples for
Laravel/Django/FastAPI included — see [Adapting to another stack](#adapting-to-another-stack)); skip
`/visual-setup` entirely unless you want screenshot review.

**Enforcement:** soft — skills fill config; downstream gates surface gaps later.

### 2 · Definition — *business analysis · Design Thinking · HCD*

**Why.** The problem space. Building the wrong thing correctly is the most expensive mistake — pin the
user, the job, and the solution shape before a backlog exists.

**Run.**
```
/discovery       # iterative requirements/PRD/HCD interview → product brief + INVEST stories + threat model
/design-import   # OPTIONAL — pull a design into a spec via Google Stitch MCP
```

**You can:** turn a fuzzy idea into a `docs/discovery/<slug>.md` brief; capture **personas** as full
HCD profiles in `docs/personas/<slug>.md` (jobs, goals, pains/gains, context, scenario), indexed from
`PRODUCT.md`; seed the standing vision (`PRODUCT.md`) and design language (`DESIGN.md`).

**Enforcement:** soft — skill-guided. Discovery's own DoR requires the persona + job-to-be-done to be
explicit before it hands off.

### 3 · Planning — *Agile backlog shaping*

**Why.** The solution space. Turn the brief into small, independent, **traceable** cards that satisfy a
Definition of Ready — so Execution has only well-formed work to pull.

**Run.**
```
/story-map       # user journey × release-slice view; reconciles map ↔ roadmap both ways
/planner         # write a roadmap task (Feature or Fix) with full DoR; reads the code map first
/sprint-start    # audit every planned task for DoR before a sprint (hard gate)
```

**You can:** see the journey above the flat backlog and find gaps. Every task carries a **`Journey:`
coordinate**, so `/story-map` flags both **GAPS** (a journey step with no task) and **ORPHANS** (a task
pointing at no real step) — real bidirectional traceability. Task **dependencies** are first-class:
`/ship-task open` won't start a task until its dependencies are delivered. `/planner` validates each
task's persona against `PRODUCT.md`.

**Enforcement:** **hard gate on DoR** (checked by `/sprint-start` and `/start-task`), but by skill
logic — the fail-closed hook fires at the Execution boundary.

### 4 · Execution — *build · verify · ship*

**Why.** Deliver each card as a reviewed, tested increment. This is where the hooks bite.

**Run — autonomous (recommended):**
```
/ship-task 1.1        # one task by ID — tests → code → reviews → PR, no input between steps
/ship-task open       # batch: every ready task whose dependencies are delivered, priority-ordered
```

`/ship-task` hands control back on exactly three things: a task that isn't DoR-ready, tests
`/debugger` couldn't fix after 2 tries, or a review blocker. Otherwise it runs to an open PR. In batch
mode a blocking task is recorded and the run continues, returning a summary.

**What the pipeline runs per task:**

| Step | Agent | Runs when |
|------|-------|-----------|
| 0 | Validate | Always — DoR check |
| 1 | Start | Always — branch + `.current-task` |
| 2 | Schema | Schema impact = `Migration` |
| 3 | Test Writer (RED) | Always — tests from criteria; **hard-stops if a RED test passes** (vacuous) |
| 3b | Locate (scout) | Always — cheap Haiku pass; scopes the change-set |
| 4 | Coder **or** Debugger | `/coder` for a Feature, `/debugger` for a `Type: Fix` |
| 5 | Test Writer (GREEN) | Always — confirms all tests pass |
| 5b | Debugger (self-repair) | If GREEN fails — auto root-cause + fix, retries up to 2× |
| 6 | Docs | API/schema/UI changed — or modules moved (refreshes the code map) |
| 7 | Commit | Always — lint + commit before reviews |
| 8–11b | UX · Perf (static+measured) · QA · Security · Dep-audit | In parallel; **any blocker stops the pipeline** |
| 12 | PR Reviewer | Always — marks roadmap done, opens PR/MR |

**Run — manual (step through it yourself):** `/start-task` → `/schema-agent` → `/test-writer` (RED) →
`/locate` → `/coder` (or `/debugger`) → `/test-writer` (GREEN) → reviews (`/ux-review`,
`/perf-review`, `/perf-measure`, `/security-audit`, `/dep-audit`, `/qa-tester`, `/visual-review`) →
`/docs`, `/diagram` → `/commit` → `/pr-reviewer`. `/refactor` and `/usability-test` on demand;
`/webapp-testing` to drive the live app.

**You can:** watch the whole loop or drive it stepwise; verify acceptance criteria with `/qa-tester`
(automated) and then do **true UAT yourself at the PR** before merging.

**Enforcement:** **hard, fail-closed.** No edit to gated paths without an active, roadmap-listed task
on the correct branch; no commit to `main`; Conventional Commits required; only `/pr-reviewer` pushes;
reviewers have no edit tools.

### 5 · Maintenance — *run & evolve*

**Why.** Post-delivery reality: bugs, tech debt, dependency drift. Fixes are first-class work, not
side-channel edits.

**Run.**
```
/debugger        # a Type: Fix card — reproduce, root-cause, minimal fix (regression test first)
/dep-audit       # SCA scan for vulnerable / outdated dependencies (OWASP A06)
/refactor        # behaviour-preserving cleanup, guarded by green tests
/perf-measure    # bundle / Web Vitals / query EXPLAIN vs budget
/roadmap-status  # progress; mark done; archive delivered blocks
```

**You can:** fix a bug the right way — but it must exist as a `Type: Fix` card *before* any code, with
**no exception** in the roadmap gate.

**Enforcement:** hard — same gate as Execution.

### ⟳ Governance, Communication & Continuous Improvement

Runs across every phase — this is where reporting and ceremonies live (they *steer and close*, they
don't shape the backlog).

```
/report          # branded progress report + PDF/PPTX deck (classical · notebooklm · sketch · illustrated)
/retro           # end-of-sprint retrospective → action items feed /planner
/usability-test  # heuristic eval + real-user protocol + findings synthesis (HCD)
/diagram         # Mermaid ERD / architecture / sequence / flow, embedded in docs
/roadmap-status  # status, done-marking, archiving
```

---

## The two enforcement layers

The lifecycle above is *behaviour*. Two layers turn it from a suggestion into a boundary:

- **Agents** ([`.claude/agents/`](.claude/agents/)) — the *envelope*: least-privilege tools + a
  right-sized model per role. Report-only reviewers have **no Edit/Write**; `/locate`,
  `/visual-review`, `/code-map` are read-only; only `/pr-reviewer` can push. Opus for hard
  builders/auditors, Sonnet for reviewers, Haiku for cheap routing. `/ship-task` dispatches every step
  through these, so least privilege is a hard boundary, not documentation.
- **Hooks** ([`.claude/settings.json`](.claude/settings.json) + [`stack-profile.sh`](.claude/hooks/stack-profile.sh))
  — the *backstop*: hard PreToolUse blocks (roadmap gate, branch gate, no-commit-to-main, Conventional
  Commits, destructive-DB, shell-write, visual-update) + PostToolUse warnings (soft-delete, secrets,
  doc/code-map reminders). Every stack-specific pattern lives in `stack-profile.sh` — retarget a stack
  by editing one file, never the hook scripts.

Agents are tool-level (no Edit at all); fine-grained path rules stay the hooks' job — the two layers
are complementary.

---

## Running unattended

For batch / CI / cron with no interactive login: `/ship-task open` drains the ready backlog
autonomously, and unattended push + PR work headless once a token is in the environment
(`GH_TOKEN` for GitHub `gh`, `GITLAB_TOKEN` for GitLab `glab`; set the forge in `.claude/context.md`).
**Never commit the token** — env var only. Note the pipeline ships *up to the PR, not through merge*:
a task shipped-but-unmerged doesn't satisfy dependents until you merge, so multi-dependency sprints
need merges between runs.

---

## Project knowledge — two tiers

The pipeline separates *how the agent works* from *what it knows*, and splits knowledge by how often
it's needed:

- **Tier 1 — operational (required, read every run):** `CLAUDE.md`, `.claude/context.md`,
  `docs/ROADMAP.md`. Kept lean because every agent loads them each task.
- **Tier 2 — knowledge (optional, read when relevant):** standing entrypoints that index the
  per-feature docs the pipeline generates. Agents fall back to `.claude/context.md` if absent.

| Tier-2 doc | Holds | Indexes | Read by |
|---|---|---|---|
| `PRODUCT.md` | Vision, users, non-goals | `docs/discovery/`, `docs/personas/` | `/discovery`, `/planner` |
| `DESIGN.md` | Design language & feeling | `docs/design/` | `/design-import`, `/ux-review` |
| `docs/ARCHITECTURE.md` | System shape, decisions, deep specs | — | `/coder`, `/schema-agent`, `/perf-review`, `/security-audit`; kept current by `/docs` |

**The one rule against drift:** a fact lives in exactly one tier. Exact tokens/badge classes →
`.claude/context.md`, not `DESIGN.md`. The short isolation-key rule → `.claude/context.md`; its
rationale → `docs/ARCHITECTURE.md`.

---

## Setup details

### 1. Copy the template into your project

```bash
# Option A — use as a GitHub/GitLab template repository (recommended): "Use this template", then clone.
# Option B — copy into an existing project:
git clone https://[your-forge]/claude-pipeline-template temp-template
cp -r temp-template/.claude your-project/
cp -r temp-template/.github your-project/
cp temp-template/CLAUDE.md your-project/
cp temp-template/docs/ROADMAP.md your-project/docs/
# Optional Tier-2 docs (or let /discovery, /design-import create them on demand):
cp temp-template/PRODUCT.md temp-template/DESIGN.md your-project/
cp temp-template/docs/ARCHITECTURE.md your-project/docs/
cp temp-template/.gitignore your-project/   # merge, don't overwrite
rm -rf temp-template
```

### 2. Run `/setup` (or do it by hand)

`/setup` fills what follows; these are the files it writes, for when you'd rather configure by hand:

- **`.claude/context.md`** — the only file that changes per project (read by every agent): project
  name, stack, commands, absolute rules, isolation key, roles, UI conventions.
- **`CLAUDE.md`** — the `[CONFIGURE]` blocks (project, stack, commands, absolute rules — keep in sync
  with `context.md`).
- **`.claude/hooks/stack-profile.sh`** — stack patterns (only if not React/Next/Prisma).
- **`.github/workflows/ci.yml`** — ORM generate step, env vars, the `test:coverage` script name.
- **`docs/ROADMAP.md`** — set the date, add your domains to the status table, plan sprint 1.

---

## What to customise per project

| File | What to change |
|------|---------------|
| `.claude/context.md` | Everything — this is the per-project configuration |
| `CLAUDE.md` | `[CONFIGURE]` sections — stack, commands, absolute rules |
| `.claude/hooks/stack-profile.sh` | All hook patterns (ORM delete, audit table, sensitive fields, gated paths, migrations, code-map command…) — one file |
| `.github/workflows/ci.yml` | ORM generate command, env vars, build command |
| `docs/ROADMAP.md` | Domain names in the global status table |
| `PRODUCT.md` · `DESIGN.md` · `docs/ARCHITECTURE.md` | **Optional** Tier-2 docs — skills create/update them on demand |

Everything else works as-is.

---

## Adapting to another stack

The pipeline ships configured for **React / Next.js · Prisma · TypeScript · Vitest**, but the
orchestration is language-agnostic — skills, gates, TDD loop, and reviews don't care what stack you
use. Only two layers carry stack-specifics:

1. **`.claude/context.md`** — your commands, ORM, validation library, UI conventions. The biggest lever.
2. **`.claude/hooks/stack-profile.sh`** — every stack-bound pattern the guard hooks match. The hook
   scripts are generic; they read these variables.

So retargeting means editing **two files**, not rewriting shell scripts. `stack-profile.sh` ships with
worked overrides for **Laravel (Eloquent/PHPUnit)**, **Django**, and **FastAPI (SQLAlchemy/Alembic)** —
copy the block for your stack, adjust, done. Any variable left unset keeps the Prisma/Next default.
You'll also swap the JS-specific reference skills (`schema-agent` for your migration tool, the
`prisma`/`lint`/`test` helpers) and `ci.yml`. The orchestration and review skills carry over unchanged.

---

## File structure

```
.claude/
  context.md          ← fill this in per project (read by all agents)
  code-map.md         ← generated router index (areas → key files → deps); read by /planner, /locate
  settings.json       ← hook configuration
  hooks/              ← shell gates (13 guards + 3 reminders)
    stack-profile.sh  ← all stack-specific patterns live here (retarget here, not in the hooks)
  agents/             ← 21 agent definitions (tool scope + model per role; ship-task dispatches via these)
  skills/             ← 32 skills (behaviour; agents reference these) — setup, discovery, planner,
                        ship-task, start-task, coder, debugger, test-writer, locate, schema-agent,
                        code-map, ux-review, perf-review, perf-measure, qa-tester, security-audit,
                        dep-audit, refactor, docs, diagram, webapp-testing, pr-reviewer, sprint-start,
                        commit, story-map, roadmap-status, design-import, report, retro,
                        usability-test, visual-setup, visual-review
.github/workflows/ci.yml   ← lint + test:coverage + build on every PR
docs/
  ROADMAP.md          ← DoR / DoD / task template + sprint planning  (Tier-1)
  LIFECYCLE.md        ← the phase view of the pipeline (this README's companion)
  ARCHITECTURE.md     ← system shape, decisions, deep specs  (Tier-2, optional)
  discovery/          ← per-feature product briefs (/discovery)
  personas/           ← full HCD persona profiles (/discovery)
  design/             ← per-screen design specs (/design-import)
CLAUDE.md             ← project instructions for Claude Code  (Tier-1)
PRODUCT.md            ← product vision; indexes discovery/ + personas/  (Tier-2, optional)
DESIGN.md             ← design language; indexes design/  (Tier-2, optional)
.gitignore            ← includes .current-task
```
