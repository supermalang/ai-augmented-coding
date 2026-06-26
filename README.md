# claude-pipeline-template

A reusable Claude Code multi-agent development pipeline. Drop it into any project to get:

- **Autonomous task execution** — `/ship-task <ID>` chains all agents from planning to PR with no human input between steps
- **TDD by default** — tests are written from acceptance criteria *before* the coder touches a file
- **Structured review gates** — security, UX, performance, and QA reviews run in parallel; any blocker stops the pipeline before the PR opens
- **Least-privilege agents** — every pipeline role runs as a tool-scoped agent (auditors can't edit code, only the PR agent can push) and is right-sized to a model
- **Shell-enforced guards** — hooks block edits without an active task, commits to protected branches, and destructive DB operations
- **Coverage enforcement** — Vitest thresholds fail CI if coverage drops
- **Layered project knowledge** — a two-tier doc model keeps the every-run context lean while vision (`PRODUCT.md`), design (`DESIGN.md`), and architecture (`docs/ARCHITECTURE.md`) grow on demand as the pipeline builds

---

## Getting started

**Prerequisites:** [Claude Code](https://claude.com/claude-code) installed, and a git repository.

The fastest path from zero to your first agent-built PR:

1. **Add the template** — copy `.claude/`, `CLAUDE.md`, and `docs/ROADMAP.md` into your repo (details in [Setup](#setup-5-minutes) below).
2. **Configure two files** — fill in `.claude/context.md` (commands, stack, absolute rules, isolation key) and the `[CONFIGURE]` blocks in `CLAUDE.md`. **This is the engine — nothing works until these are filled in;** every agent reads them on each run. That's all you *must* fill in: the optional vision/design/architecture docs ([two tiers](#project-knowledge--two-tiers)) fill in as you build.
3. **Non-JS stack?** — override `.claude/hooks/stack-profile.sh` for your stack (one file; Laravel/Django/FastAPI examples included). On the default React/Next/Prisma stack, skip this. See [Adapting to another stack](#adapting-to-another-stack).
4. **Seed the roadmap** — add one task to `docs/ROADMAP.md`, or let `/planner` write it.
5. **Build it** — in Claude Code:

   ```
   /discovery        # optional — scope a fuzzy idea into a brief (PRD + threat model); seeds PRODUCT.md
   /design-import    # optional — pull a design into a spec; seeds DESIGN.md
   /planner          # turn it into a roadmap task with acceptance criteria
   /ship-task <ID>   # autonomous: tests → code → reviews → PR
   ```

   `/ship-task` only hands control back on three things: a task that isn't ready (DoR), tests `/debugger` couldn't fix after 2 tries, or a review blocker. Otherwise it runs all the way to an open PR.

6. **Review the PR** — the pipeline opens it; you merge.

> **Tip:** the first time, point it at a tiny task (one field or one endpoint) to watch the whole loop run before trusting it with anything big.

---

## Setup (5 minutes)

### 1. Copy the template into your project

```bash
# Option A — use as a GitHub/GitLab template repository (recommended)
# Click "Use this template" in the UI, clone your new repo.

# Option B — copy files into an existing project
git clone https://[your-gitlab]/claude-pipeline-template temp-template
cp -r temp-template/.claude your-project/
cp -r temp-template/.github your-project/
cp temp-template/CLAUDE.md your-project/
cp temp-template/docs/ROADMAP.md your-project/docs/  # if docs/ exists
# Optional Tier-2 knowledge docs (or let /discovery, /design-import create them on demand):
cp temp-template/PRODUCT.md temp-template/DESIGN.md your-project/
cp temp-template/docs/ARCHITECTURE.md your-project/docs/
cp temp-template/.gitignore your-project/  # merge, don't overwrite
rm -rf temp-template
```

### 2. Fill in `.claude/context.md`

This is the only file that changes per project. Every pipeline agent reads it at the start of each task. Fill in:

- Project name and description
- Tech stack and key commands
- Absolute rules (non-negotiable constraints)
- Data isolation key (e.g. `tenantId`, `orgId`)
- Roles and access levels
- UI language and component conventions

### 3. Fill in `CLAUDE.md`

Update the sections marked `[CONFIGURE]`:
- Project description
- Tech stack
- Commands
- Absolute rules (same as `context.md` — keep in sync)

> Architecture detail no longer lives in `CLAUDE.md` — it's in the optional Tier-2 doc
> `docs/ARCHITECTURE.md` (see [Project knowledge — two tiers](#project-knowledge--two-tiers)).
> Fill it in when the system is complex enough to warrant it; skip it for small projects.

### 4. Adapt the hooks (only if not React/Next/Prisma)

All stack-specific hook patterns live in **one file** — `.claude/hooks/stack-profile.sh`. Override its variables (ORM delete call, destructive DB command, audit table, sensitive fields, gated paths, migrations directory…) instead of editing the hook scripts, which are generic. It ships with Laravel/Django/FastAPI examples. On the default React/Next/Prisma stack, skip this. See [Adapting to another stack](#adapting-to-another-stack).

### 5. Adapt the CI workflow

Edit `.github/workflows/ci.yml`:
- Remove the `Generate ORM types` step if you don't use Prisma
- Update env vars in the `Build` step
- Adjust the `test:coverage` script name if different in your `package.json`

### 6. Initialise your roadmap

Edit `docs/ROADMAP.md`:
- Set the date
- Add your domain names to the Global status table
- Plan your first sprint

---

## Usage

### Start a task autonomously

```
/ship-task 1.1
```

The pipeline will:
1. Validate DoR (stops here if any field is missing)
2. Create a feature branch and set `.current-task`
3. Run migrations if needed (`/schema-agent`)
4. Write tests (RED — must fail)
5. Implement until tests pass (`/coder`); if GREEN fails, `/debugger` auto-fixes and retries (up to 2×)
6. Update docs if the API, schema, or UI changed (`/docs`)
7. Commit the implementation
8. Run reviews in parallel: UX, perf (static + measured), QA, security, and dependency/SCA
9. Stop if any review returns blockers
10. Open a PR

Human touchpoints: DoR failure → fix the roadmap. Tests still failing after auto-fix → fix the code. Review blocker → resolve it. **PR opened → run human UAT against the PR, tick the UAT checklist, then merge.** The pipeline is autonomous up to the PR; final user acceptance is always yours.

### Plan a new task

```
/planner
```

Or just describe what you want — if no matching task exists in the roadmap, `/planner` is invoked automatically.

### Check roadmap progress

```
/roadmap-status
```

### Start a sprint

```
/sprint-start
```

Audits all planned tasks for DoR before the sprint begins.

---

## Pipeline overview

| Step | Agent | Runs when |
|------|-------|-----------|
| 0 | Validate | Always — DoR check |
| 1 | Setup | Always — branch + `.current-task` |
| 2 | Schema | `impactSchema = Migration` |
| 3 | Test Writer (RED) | Always — writes tests, confirms they fail |
| 3b | Locate (scout) | Always — cheap read-only Haiku pass; scopes the change-set so the coder loads only what it needs |
| 4 | Coder | Always — implements to make tests pass, from the scout's change-set |
| 5 | Test Writer (GREEN) | Always — confirms all tests pass |
| 5b | Debugger (self-repair) | If GREEN fails — auto root-causes + fixes, retries (up to 2×) |
| 6 | Docs | Task touches API, schema, or UI |
| 7 | Commit | Always — lint + commit before reviews |
| 8 | UX Review | Task touches UI |
| 9 | Perf Review (static) | Task touches ORM queries or API routes |
| 9b | Perf Measure | Perf-sensitive task — bundle/Web Vitals/EXPLAIN vs budget |
| 10 | QA Tester | Always |
| 11 | Security Audit | Always |
| 11b | Dep Audit | Always — SCA scan for vulnerable dependencies |
| — | Blocker gate | Stops pipeline if any review (8–11b, parallel) returns blockers |
| 12 | PR Reviewer | Always — marks roadmap done, opens PR |

---

## File structure

```
.claude/
  context.md          ← fill this in per project (read by all agents)
  settings.json       ← hook configuration
  hooks/              ← shell gates (13 hooks)
    stack-profile.sh  ← all stack-specific patterns live here (retarget here, not in the hooks)
  agents/             ← 16 agent definitions (tool scope + model per role; ship-task dispatches via these)
  skills/             ← 24 agent skills (behaviour; agents reference these)
    discovery/        ← requirements/PRD/HCD kickoff + threat model
    design-import/    ← design-to-code via Google Stitch MCP
    ship-task/        ← autonomous orchestrator
    planner/          ← roadmap task creation
    start-task/       ← DoR validation + branch
    coder/            ← implementation
    locate/           ← read-only change-set scout (cheap; runs before coder)
    test-writer/      ← TDD (RED + GREEN modes)
    schema-agent/     ← migrations
    ux-review/        ← UI review
    perf-review/      ← query performance (static)
    perf-measure/     ← measured perf (bundle, Web Vitals, EXPLAIN)
    qa-tester/        ← UAT + screenshots
    security-audit/   ← OWASP + absolute rules
    dep-audit/        ← dependency/SCA vulnerability scan
    refactor/         ← behaviour-preserving cleanup
    debugger/         ← reproduce + root-cause + fix
    docs/             ← README/API/CHANGELOG updates
    diagram/          ← Mermaid diagrams in docs
    webapp-testing/   ← live browser verification (throwaway)
    pr-reviewer/      ← DoD + PR opening (+ audit mode)
    sprint-start/     ← sprint DoR audit
    commit/           ← conventional commits
    roadmap-status/   ← roadmap progress
.github/
  workflows/
    ci.yml            ← lint + test:coverage + build on every PR
docs/
  ROADMAP.md          ← DoR / DoD / task template + sprint planning  (Tier-1)
  ARCHITECTURE.md     ← system shape, decisions, deep specs  (Tier-2, optional)
  discovery/          ← per-feature product briefs (written by /discovery)
  design/             ← per-screen design specs (written by /design-import)
CLAUDE.md             ← project instructions for Claude Code  (Tier-1)
PRODUCT.md            ← product vision; indexes docs/discovery/  (Tier-2, optional)
DESIGN.md             ← design language; indexes docs/design/  (Tier-2, optional)
.gitignore            ← includes .current-task
```

### Project knowledge — two tiers

The pipeline separates *how the agent works* from *what it knows*, and splits knowledge by how
often it's needed:

- **Tier 1 — operational (required, read every run):** `CLAUDE.md`, `.claude/context.md`,
  `docs/ROADMAP.md`. Kept lean because every agent loads them on each task.
- **Tier 2 — knowledge (optional, read when relevant):** `PRODUCT.md`, `DESIGN.md`,
  `docs/ARCHITECTURE.md`. Standing entrypoints that index the per-feature docs the pipeline
  generates (`docs/discovery/`, `docs/design/`). Each is optional — agents fall back to
  `.claude/context.md` if it's absent, and `/discovery` / `/design-import` create `PRODUCT.md` /
  `DESIGN.md` on first use.

| Tier-2 doc | Holds | Indexes | Read by |
|---|---|---|---|
| `PRODUCT.md` | Vision, users, non-goals | `docs/discovery/<slug>.md` | `/discovery`, `/planner` |
| `DESIGN.md` | Design language & feeling | `docs/design/<slug>.md` | `/design-import`, `/ux-review` |
| `docs/ARCHITECTURE.md` | System shape, decisions, deep specs | — | `/coder`, `/schema-agent`, `/perf-review`, `/security-audit`; kept current by `/docs` |

**The one rule against drift:** a fact lives in exactly one tier. Exact tokens/badge classes →
`.claude/context.md`, not `DESIGN.md`. The short isolation-key rule → `.claude/context.md`; its
rationale and edge cases → `docs/ARCHITECTURE.md`.

---

## What to customise per project

| File | What to change |
|------|---------------|
| `.claude/context.md` | Everything — this is the per-project configuration |
| `CLAUDE.md` | `[CONFIGURE]` sections — stack, commands, architecture |
| `.claude/hooks/stack-profile.sh` | All hook patterns (ORM delete, audit table, sensitive fields, gated paths, migrations…) — one file |
| `.github/workflows/ci.yml` | ORM generate command, env vars, build command |
| `docs/ROADMAP.md` | Domain names in the global status table |
| `PRODUCT.md` · `DESIGN.md` · `docs/ARCHITECTURE.md` | **Optional** Tier-2 knowledge docs — fill in when useful; the relevant skills create/update them on demand |

Everything else works as-is.

---

## Adapting to another stack

The pipeline ships configured for **React / Next.js · Prisma · TypeScript · Vitest**, but the orchestration is language-agnostic — the skills, gates, TDD loop, and reviews don't care what stack you use. Only two layers carry stack-specifics:

1. **`.claude/context.md`** — your commands, ORM, validation library, and UI conventions. Every agent reads it. This is the biggest lever.
2. **`.claude/hooks/stack-profile.sh`** — every stack-bound pattern the guard hooks match against (hard-delete call, destructive DB command, gated paths, audit table, sensitive fields, migrations directory, doc/rebuild commands). The hook scripts themselves are generic; they just read these variables.

So retargeting a stack means editing **two files**, not rewriting shell scripts. `stack-profile.sh` ships with worked override examples for **Laravel (Eloquent/PHPUnit)**, **Django**, and **FastAPI (SQLAlchemy/Alembic)** — copy the block for your stack, adjust, done. Any variable you leave unset keeps the Prisma/Next default.

You'll also swap the JS-specific reference skills (`schema-agent` for your migration tool, the `prisma`/`lint`/`test` helpers) and `.github/workflows/ci.yml`. The ~15 orchestration and review skills carry over unchanged.
