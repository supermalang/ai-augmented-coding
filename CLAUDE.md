# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

> **Setup:** fill in the sections marked `[CONFIGURE]` before using the pipeline.
> All agents also read `.claude/context.md` — fill that in first.
> Vision, design, and deep architecture live in optional Tier-2 docs that fill in as you build —
> see [Project knowledge — two tiers](#project-knowledge--two-tiers).

---

## Project

**[CONFIGURE]** — replace this section with your project name, purpose, and key constraints.

---

## Tech stack

**[CONFIGURE]** — list your frameworks, versions, and key libraries.

---

## Commands

**[CONFIGURE]** — list your dev, build, lint, test, and database commands.

```bash
npm run dev           # Dev server
npm run build         # Production build
npm run lint          # ESLint
npm run test:run      # Vitest (single run)
npm run test:coverage # Vitest + coverage thresholds
```

---

## Architecture

The deep technical reference — system shape, components, data model, auth flow, the standard API
route pattern, trust boundaries, and hot paths — lives in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
It is read **when a task needs it** (by `/coder`, `/schema-agent`, `/perf-review`,
`/security-audit`), not on every run. Keep it current via `/docs`.

This split is deliberate (see [Project knowledge — two tiers](#project-knowledge--two-tiers) below):
short operational facts every agent needs each run stay in `.claude/context.md`; deep architectural
explanation lives in `docs/ARCHITECTURE.md`.

---

## Project knowledge — two tiers

The pipeline separates *how the agent works* from *what it knows*, and within knowledge separates
the every-run essentials from the read-when-relevant depth.

**Tier 1 — operational (required, read every run).** Keep these lean.

| File | Holds |
|---|---|
| `CLAUDE.md` (this file) | Instructions to the agent — rules, workflow, which skill when |
| [`.claude/context.md`](.claude/context.md) | Concise operational facts — stack, commands, absolute rules, isolation key, UI conventions |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | The work — tasks, DoR/DoD, sprints |

**Tier 2 — knowledge (optional, read when relevant).** Standing entrypoints that index the
per-feature docs the pipeline generates. Each is optional — agents fall back to `.claude/context.md`
if it's absent.

| File | Holds | Indexes | Read by |
|---|---|---|---|
| [`PRODUCT.md`](PRODUCT.md) | Product vision, users, non-goals | `docs/discovery/<slug>.md` | `/discovery`, `/planner` |
| [`DESIGN.md`](DESIGN.md) | Design language & feeling | `docs/design/<slug>.md` | `/design-import`, `/ux-review` |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System shape, decisions, deep specs | — | `/coder`, `/schema-agent`, `/perf-review`, `/security-audit`; kept current by `/docs` |

Rule against drift: a fact lives in exactly **one** tier. Exact tokens/classes → `context.md`,
not `DESIGN.md`. Short isolation-key rule → `context.md`; its rationale and edge cases →
`ARCHITECTURE.md`.

---

## Active roadmap

Planned work is tracked in [`docs/ROADMAP.md`](docs/ROADMAP.md).

### Gate before coding

**Before writing any implementation code, test, or documentation, confirm the task exists in `docs/ROADMAP.md` and satisfies the Definition of Ready (DoR).**

**Step 1 — Task exists?**
- If the task is listed → proceed to Step 2.
- If the task is not listed → automatically invoke `/planner` to create it. Do not ask the user for permission — unplanned work always needs a roadmap entry before code is written. Once `/planner` confirms DoR is met, continue to Step 2.

**Step 2 — DoR satisfied?**
Check every DoR item at the top of `docs/ROADMAP.md`. If any item is missing → stop. Fill the missing fields before writing any code.

**Step 3 — Proceed**
- Read the task's acceptance criteria in full.
- Check schema impact — if `Migration`, run your migration command first.

This gate applies to all feature and fix tasks. It does not apply to bug fixes on already-implemented features, tooling changes, or documentation updates.

### When assigned a task

**Recommended — fully autonomous:** `/ship-task <ID>` chains all agents automatically with skip logic, and only pauses on DoR failure, test failure, or when the PR URL is ready for your review.

**Manual — step by step:** invoke each skill in order.

| Step | Skill | Run when |
|---|---|---|
| −1 | `/discovery` | Requirements are unclear — interviews the user, writes a product brief, then feeds `/planner` |
| 0 | `/planner` | Task does not exist in roadmap yet (consumes the discovery brief if one exists) |
| 1 | `/start-task <ID>` | Always — validates DoR, sets `.current-task`, creates branch |
| 2 | `/schema-agent` | Schema impact = `Migration` |
| 3 | `/test-writer` (RED) | Always — writes tests from criteria, confirms they fail |
| 3b | `/locate` | Non-trivial change — scouts the minimal change-set (files, line ranges, call path) so `/coder` edits surgically; skip when the target is obvious |
| 4 | `/coder` | Always — implements until RED tests pass (starting from the scout's change-set) |
| 5 | `/test-writer` (GREEN) | Always — re-runs tests, confirms pass |
| 6 | `/ux-review` | Task touches UI |
| 7 | `/perf-review` | Task touches ORM queries or async fetching |
| 7b | `/perf-measure` | Perf-sensitive task — confirm `/perf-review` findings with real numbers (bundle, Web Vitals, EXPLAIN) |
| 8 | `/qa-tester` | Always |
| 9 | `/security-audit` | Always |
| 9b | `/dep-audit` | Always before shipping — SCA scan for vulnerable dependencies (OWASP A06) |
| 10 | `/docs` | Task changes API, schema, setup, commands, or user-facing behaviour |
| 11 | `/pr-reviewer` | Always — DoD check, roadmap update, opens PR |

A design can be imported up front with `/design-import` (Google Stitch MCP) before `/planner`, and `/diagram` can be used at any point to add Mermaid ERDs, architecture, sequence, or workflow diagrams to the docs.

**Discovery → planning flow:** when a request arrives without a clear problem definition, start at `/discovery`. It runs an iterative requirements/PRD/HCD interview and writes a product brief to `docs/discovery/<slug>.md` with INVEST-shaped user stories. `/planner` then turns those stories into roadmap tasks. Skip `/discovery` when the task is already well understood and goes straight to `/planner`.

---

## Absolute rules

**[CONFIGURE]** — paste your absolute rules here (also in `.claude/context.md`).

1. **Soft delete only** — never call `.delete()` directly; set `deletedAt = new Date()`
2. **Audit log is insert-only** — never update or delete audit records
3. **Always filter by isolation key** — every query scoped to active context
4. **Never expose secrets** — no password hashes or tokens in API responses
5. **Always validate with Zod** — parse all API input before touching the database

---

## Engineering principles

These apply to every agent that writes code (`/coder`, `/refactor`, `/debugger`) — how to work, not what the rules are. Adapted from Andrej Karpathy's observations on LLM coding pitfalls.

1. **Think before coding** — surface hidden assumptions and ambiguities *before* writing code. If the task is underspecified, ask or check the roadmap/acceptance criteria; don't guess and build the wrong thing.
2. **Simplicity first** — write the minimal code that satisfies the acceptance criteria. No speculative abstractions, no features that aren't in the task. The smallest correct change wins.
3. **Surgical changes** — touch only what the task requires. Don't refactor adjacent code, rename unrelated symbols, or reformat files you didn't need to change. Structural cleanup is `/refactor`'s job, behind green tests.
4. **Goal-driven execution** — define what "done" looks like as verifiable criteria (the task's acceptance criteria and tests), then work until they're objectively met. Don't declare done by vibe — prove it with passing tests.

---

## Contribution workflow

### Branches

Always branch from `develop`. Allowed prefixes: `feature/`, `fix/`, `chore/`, `hotfix/`, `refactor/`, `test/`, `docs/`, `ci/`, `release/`. Never commit directly to `main` or `develop`.

### Commit messages — Conventional Commits

Format: `type(scope): short description`

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`, `style`, `build`, `revert`.

---

## Local skills

Skills are slash commands in `.claude/skills/`.

**Pipeline agents:**

| Skill | Role |
|---|---|
| `discovery` | Product discovery kickoff — iterative requirements/PRD/HCD interview; writes a product brief that feeds `/planner` |
| `ship-task` | Autonomous orchestrator — chains all pipeline agents with skip logic, ships to a PR |
| `sprint-start` | Sprint kickoff — verify all planned tasks satisfy DoR |
| `planner` | Write a new task in the roadmap using the full template |
| `start-task` | Validate DoR, write `.current-task`, create feature branch |
| `schema-agent` | Design and apply schema migrations |
| `coder` | Implement a task — frontend + backend |
| `test-writer` | Write Vitest unit tests + E2E specs (RED and GREEN modes) |
| `locate` | Read-only change-set scout — finds the minimal files/line ranges and call path to touch before `/coder` (cheap, runs on Haiku) |
| `ux-review` | Review edited UI — visual harmony, conventions, accessibility |
| `perf-review` | Audit ORM queries — N+1, pagination, over-fetching (static) |
| `perf-measure` | Measure performance — bundle budget, Web Vitals, query EXPLAIN |
| `qa-tester` | UAT checklist + screenshot review |
| `security-audit` | OWASP Top 10 + project absolute rules |
| `dep-audit` | Dependency/SCA scan — vulnerable & outdated packages (OWASP A06) |
| `pr-reviewer` | PR gate (DoD, roadmap, opens PR) + read-only audit mode |

**Reference skills:**

| Skill | When to use |
|---|---|
| `commit` | Conventional Commits-compliant commit |
| `refactor` | Behaviour-preserving structural cleanup, guarded by green tests |
| `debugger` | Reproduce, root-cause, and minimally fix a bug |
| `docs` | Update README, API docs, schema cheatsheet, and CHANGELOG from the diff |
| `diagram` | Add Mermaid diagrams to docs — ERD, architecture, sequence, workflow, pipeline |
| `design-import` | Design-to-code via Google Stitch MCP — pulls tokens/layout, writes a design spec for `/coder` |
| `webapp-testing` | Drive the running app in a browser — live screenshots, DOM, console logs (throwaway, not E2E) |
| `domain-rules` | Verify the project's absolute rules |
| `roadmap-status` | Check roadmap progress, mark tasks done |
| `prisma` | Migrations, seed, Studio |
| `lint` | Run ESLint and report errors |
| `test` | Run Vitest and report results |

> `domain-rules`, `prisma`, `lint`, and `test` are conventional helper commands, **not** shipped as `.claude/skills/` files in this template. Add them per project if you want them as dedicated skills, or just run the underlying commands directly.

---

## Agents (runtime enforcement layer)

Skills define *behaviour*; **agents** in `.claude/agents/` define the *envelope* — which tools each role may use and which model it runs on. Each agent file is thin: frontmatter (`tools:` + `model:`) plus a one-line body pointing at its `SKILL.md`, so the skill stays the single source of truth and the two can't drift.

`/ship-task` dispatches every step through these agents via the workflow's `agentType` option. The point is **least privilege as a hard boundary**, not just documentation:

- **Report-only reviewers** — `ux-review`, `perf-review`, `security-audit` have **no Edit/Write tools**. They find and report (`blockers`/`warnings`); a builder applies fixes. (An auditor cannot edit the code it audits.)
- **`locate`** is read-only too (Read/Grep/Glob/Bash, no Edit/Write) — a scout points at the change-set; a builder makes the change. It runs on Haiku to keep the routing step cheap.
- **`commit`** has no Edit/Write — it only stages and commits.
- **`pr-reviewer`** is the **only** agent that can `git push` / open PRs.
- **Builders** (`coder`, `debugger`, `schema-agent`, `test-writer`, `refactor`) can edit + run commands; **docs/diagram** can write docs only.
- **Models** are right-sized per role (Opus for `coder`/`debugger`/`schema-agent`/`security-audit`/`pr-reviewer`; Sonnet for most reviewers; Haiku for `commit`/`diagram`/`locate`).

Note the granularity: agent tools are **tool-level** (no Edit at all, no Bash at all), not path-level. Fine-grained rules ("edit tests but not source", "no push") remain the **hooks'** job — agents and hooks are complementary layers. When invoked **manually** as a skill (e.g. typing `/ux-review`), a role runs in the main loop with full tools and a human present; the report-only restriction applies to **autonomous** dispatch only.

---

## Automatic hooks

Configured in `.claude/settings.json`. All stack-specific patterns the hooks match against (ORM delete call, destructive DB command, gated paths, audit table, sensitive fields, migrations directory, doc/rebuild commands) live in **`.claude/hooks/stack-profile.sh`** — retarget a stack by editing that one file, never the hook scripts. The defaults target React/Next.js · Prisma · TypeScript.

### PreToolUse (hard block)

| Trigger | Hook | What it blocks |
|---|---|---|
| Bash | `guard-git-flow.sh` | Commits/pushes to `main`; warns on non-standard branch names |
| Edit / Write | `guard-branch.sh` | Editing implementation files on `develop` or `main` |
| Bash | `guard-destructive-db.sh` | Destructive database operations |
| Bash | `guard-commit-message.sh` | Non-Conventional Commits format |
| Edit / Write | `guard-roadmap-gate.sh` | Editing `src/`, `tests/`, schema without `.current-task` |
| Edit / Write | `guard-generated-files.sh` | Hand-editing auto-generated files |

### PostToolUse (warnings)

| Trigger | Hook | What it warns |
|---|---|---|
| Edit / Write | `guard-test-files.sh` | Test file modified outside of `/test-writer` |
| Edit / Write | `guard-soft-delete.sh` | Direct ORM delete detected |
| Edit / Write | `guard-audit-log.sh` | Mutation on audit log table |
| Edit / Write | `guard-expose-hash.sh` | Sensitive field exposed in API response |
| Edit / Write | `guard-secret-scan.sh` | Hardcoded secret detected (key, token, credential) |
| Edit / Write | `remind-docs-generate.sh` | Schema or API changed — regenerate docs |
| Write | `remind-docker-rebuild.sh` | New migration written — Docker image needs rebuild |
