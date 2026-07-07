---
name: performance
description: Performance skill with two modes. `review` (static) — reads the active task's changed code for N+1 queries, unbounded queries, missing pagination, over-fetching, missing indexes, and unparallelised async. `measure` (dynamic) — runs the app and checks bundle size, Core Web Vitals, and query EXPLAIN on hot paths against budgets in .claude/context.md. Mirrors the test-writer (RED/GREEN) and pr-reviewer (gate/audit) two-mode pattern. Run review after /coder; run measure on perf-sensitive work to confirm with real numbers.
---

# /performance — Performance Review & Measurement

Before starting, read `.claude/context.md` for project-specific rules, budgets, and conventions. The
**mode is given in the invocation** (`performance review` or `performance measure`); if unspecified,
default to `review`.

Two modes, one skill: **review reads the code** for anti-patterns; **measure runs the app** for real
numbers against a budget. A code read can't prove performance and a measurement can't explain *why* —
so on perf-sensitive work do both: review first, then measure.

## Permissions (per mode)

**`review` mode**
- ✅ CAN read : all project files · `git diff` · read-only commands
- ✅ CAN write : source files (**performance fixes only** — no new features, no logic changes) **when invoked manually with a human present**
- ⚠️ **Autonomous (under `/ship-task`) is report-only** — the dispatched agent runs with no source edits; it emits `blockers`/`warnings` and a builder (`/coder`/`/debugger`) applies fixes.
- ❌ CANNOT : write `docs/ROADMAP.md`, tests, or schema · push · open PRs · add features as a "perf fix"

**`measure` mode**
- ✅ CAN read : all project files
- ✅ CAN write : `.scratch/perf-measure/**` only (reports, traces — throwaway, gitignored)
- ✅ CAN run : build · bundle analyzer · Lighthouse / Web Vitals capture · `EXPLAIN`/`ANALYZE` · load tools
- ❌ CANNOT : modify source, tests, or schema (escalate fixes to `/coder`/`/refactor`) · write `docs/ROADMAP.md` · push · open PRs

If a missing **index** is found in either mode → do not edit the schema; flag it for `/schema-agent`.

---

## Mode: `review` (static)

Targeted audit of the active task's changes — database query efficiency and async patterns, not
micro-optimisations. A slow query in production is a DoS/resource-exhaustion risk as much as a
performance one.

### 1 — Identify the surface
```bash
git diff --name-only HEAD
```
Focus on DB queries (API routes, data-access layer), data-fetching server components/functions, and
functions running multiple async operations. If [`docs/ARCHITECTURE.md`](../../../docs/ARCHITECTURE.md)
exists, read its **performance-sensitive paths** — hot paths + scale assumptions tell you which
changes actually matter.

### 2 — N+1 query check
A loop that triggers a separate DB call per iteration. Check every loop / `.map()` containing an
`await db.*`. Fix with eager loading / a join (`include`) instead of per-item queries.

### 3 — Unbounded query check
Any `findMany()` / `SELECT *` without a `LIMIT` is unbounded.
- [ ] Every user-facing list query is paginated (limit + offset or cursor)
- [ ] …or has a filter narrow enough that the result set is always small (< 100 rows)
- [ ] `orderBy` / `ORDER BY` present when paginating (deterministic pages)

### 4 — Over-fetching check
- [ ] List routes use field selection (`select`) — only the fields the UI needs
- [ ] Eager-loaded relations don't pull sensitive fields [PROJECT RULE — see `.claude/context.md`]
- [ ] Large JSON/blob fields excluded from list queries; fetched on detail views only

### 5 — Missing index check
Read the schema. For every column used in a `where` in the modified files:
- [ ] Tenant/scope column indexed · [ ] `deletedAt` indexed if frequently filtered · [ ] composite index where composite queries benefit

Found one → flag for `/schema-agent`; do not modify the schema directly.

### 6 — Unparallelised async check
Independent async ops should run with `Promise.all()`. Look for consecutive `await`s that are not
data-dependent on each other.

### 7 — Report
```
🔴 Severity : Critical | High | Moderate | Low
📄 File     : src/app/api/items/route.ts:34
⚡ Category : N+1 | Unbounded | Over-fetch | Missing index | Sequential async
❌ Issue    : findMany inside a map — one query per parent item
✅ Fix      : use include: { children: true } on the parent query
```
Severities: **Critical** — unbounded on a large table or N+1 in a hot path · **High** — pagination
missing on a user-facing list · **Moderate** — over-fetching on a frequent route · **Low** —
parallelisable sequential async.

### 8 — Apply fixes (manual only)
Manual + human present: fix **Critical**/**High** immediately; present **Moderate**/**Low** for a
decision. Autonomous under `/ship-task`: **report only** — a builder applies them. Missing index →
delegate to `/schema-agent`, never edit the schema here.

### 9 — Handoff
```
✅ Performance review complete — 🔴 Critical X · 🟠 High Y · 🟡 Moderate Z
⚠️  Schema : N index additions → /schema-agent
➡️  Next   : performance measure (confirm with real numbers) → /pr-reviewer
```

---

## Mode: `measure` (dynamic)

Run the app and capture real numbers against the budgets in `.claude/context.md`.

**Prerequisites:** a build/dev command + running-app path (see `.claude/context.md`; reuse
`/webapp-testing` to drive the live app). Budgets in `.claude/context.md` — if absent, propose the
defaults below and flag them unconfirmed.

**Budgets (defaults if `.claude/context.md` is silent):**

| Metric | Default budget |
|---|---|
| Largest Contentful Paint (LCP) | < 2.5 s |
| Interaction to Next Paint (INP) | < 200 ms |
| Cumulative Layout Shift (CLS) | < 0.1 |
| Initial JS bundle (gzipped) | < 200 KB |
| Hot-path DB query | no seq scan on large tables; uses an index |

### 1 — Bundle size
Run the build + bundle analyzer (see `.claude/context.md`). Record initial/route bundle sizes
(gzipped) vs budget. Flag any single dependency dominating a bundle, and any route shipping far more
JS than its neighbours.

### 2 — Lighthouse / Core Web Vitals on key routes
For each perf-critical route (task routes + the app's main entry), capture LCP, INP, CLS, TBT — via
`/webapp-testing` (Playwright reads `web-vitals` / performance entries) or Lighthouse. Compare to budget.

### 3 — Database query plans on hot paths
For queries the task added/touched on hot paths, run `EXPLAIN` / `EXPLAIN ANALYZE` (or the ORM's
plan tooling). Check for seq scans on large tables, missing indexes, and N+1 confirmed at runtime.

### 4 — Optional: load / stress
High-traffic path + a load tool available (k6, autocannon, locust — see `.claude/context.md`): a
short load test recording p50/p95/p99 latency + error rate under load.

### 5 — Report against budget
```
📊 Performance measurement — task <ID>
📦 Bundle (initial, gzip) : 184 KB  / budget 200 KB  ✅
🎨 LCP /route             : 3.1 s   / budget 2.5 s   🔴 over
⚡ INP                    : 140 ms  / budget 200 ms  ✅
🗃️  Query <name>          : seq scan on orders (1.2M rows) 🔴 — add index on (tenantId, createdAt)
🏋️  Load p95              : 320 ms @ 50 rps          ✅
```
Lead with budget **breaches**; for each, name the likely cause + the owning agent for the fix. A
green report is a valid, valuable result — say so. Writes go only to `.scratch/perf-measure/`.

### 6 — Handoff
```
✅ Measurement complete — 🔴 breaches: N (listed) / ✅ all within budget
➡️  Next : /coder or /refactor for breaches, then re-run performance measure · else /pr-reviewer
```
> On delivery, `/pr-reviewer` records any perf blocker/breach in the task's **Delivery block** so
> `/retro` can trend the perf signal across the sprint.

---

## What performance does NOT do

- Does not add features under the guise of a perf fix; does not touch tests, schema, or the roadmap.
- `measure` does not fix code (`/coder`/`/refactor`) and does not commit its `.scratch/` reports.
- Does not modify the schema — a missing index is delegated to `/schema-agent`.
- Autonomous `review` does not edit source — it reports; a builder applies.
