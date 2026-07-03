# ROADMAP

*Dernière mise à jour : 2026-07-03*

---

## Definition of Ready (DoR)

A task must satisfy **all** of the following before any code is written. The pipeline hard-stops if any item is missing.

- [ ] All template fields filled and non-empty
- [ ] Acceptance criteria: at least 3, concrete and verifiable
- [ ] Story is **Independent and Small** — deliverable in a single sprint with no hidden dependency on unplanned work; if not, split it (INVEST I + S)
- [ ] Schema impact declared (`Migration` or `None`)
- [ ] Dependencies identified (or explicitly `None`)
- [ ] Wireframe or mockup referenced (or `N/A` with justification for non-UI tasks)
- [ ] Risk level declared (`Low` / `Medium` / `High`)

> **Hard stop:** the `guard-roadmap-gate.sh` hook blocks all edits to `src/`, `tests/`, and the schema file if `.current-task` is not set or the task ID is not found in this file.

---

## Definition of Done (DoD)

A task is done only when **all** of the following are true:

- [ ] All acceptance criteria verifiably met
- [ ] Tests written and passing at the layers the task needs (`test:coverage` above thresholds):
  - [ ] Unit — for new/changed business logic
  - [ ] Component — for new/changed UI components (states, props, interaction)
  - [ ] Integration — for new/changed API routes / DB access (real test DB)
  - [ ] E2E — for new/changed user-facing flows
  - [ ] Accessibility (axe) — no violations on new/changed UI
- [ ] No lint errors (`npm run lint`)
- [ ] Code reviewed (security, performance, UX if applicable)
- [ ] Roadmap task marked `[x]` with completion date
- [ ] PR/MR opened and linked

---

## Sprint rituals (cadence-level checks)

The DoR/DoD above are **per-task** gates. Some work is **per-sprint**, not per-task — it can't be a
task checkbox, so it lives here, verified by the sprint rituals that bracket a sprint.

**Sprint entry — checked by `/sprint-start`:**
- [ ] Every planned task satisfies the **task DoR**
- [ ] The **story map** is current — the user journey is mapped and every journey gap is planned or consciously deferred (`/story-map`). **Hard gate** (blocks the sprint) on the first sprint or any sprint adding new user-facing journeys; a reminder otherwise

**Sprint exit — checked by `/report` + `/retro`:**
- [ ] Every task taken into the sprint is DoD-done `[x]` or explicitly carried over
- [ ] **Usability** checked on the user-facing features shipped this sprint — heuristic pass at minimum, real-user sessions when scheduled (`/usability-test`); findings filed as `/planner` tasks
- [ ] Progress **report** generated for the review (`/report`)
- [ ] **Retrospective** held and action items captured (`/retro`)

> Why here and not the DoD: story mapping and usability testing are about the *product/journey across
> many tasks*, are periodic, and (for real-user testing) need humans — so they're sprint-cadence checks,
> not per-task gates. Their *outputs* become tasks, which then pass the normal DoD.

---

## Task Template

Copy this block when creating a new task via `/planner`.

```markdown
### [ID] — [Short task title]

**Sprint:** Sprint N
**Write date:** YYYY-MM-DD
**Planned date:** YYYY-MM-DD
**Completion date:** —
**Type:** Feature | Fix  *(Fix = bug on already-shipped behaviour → orchestrator routes the build to `/debugger`)*
**Risk:** Low | Medium | High
**Priority:** P0 | P1 | P2  *(P0 = must ship this sprint / blocking · P1 = important, not blocking · P2 = nice to have)*
**Dependencies:** <task IDs this blocks on, comma-separated> | None  *(batch `/ship-task open` skips a task until every dependency is delivered `[x]`)*

**Description**
One paragraph — what this task does, not how.

**User value**
As a [persona], I want [action] so that [benefit].

**Acceptance criteria**
- [ ] Criterion 1 — concrete and verifiable
- [ ] Criterion 2 — nominal case
- [ ] Criterion 3 — edge or error case

**Schema impact:** None — [reason] | Migration — [what changes]

**Components:** `src/app/...` · `src/lib/...`
**API:** `POST /api/...` · `GET /api/...`

**Change-set (locate):** N/A — greenfield | *for change-type tasks, coarse scout output reused by `/coder`:*
- Targets: `src/...` (areas to modify) · Call path: entry → change point · Ripples: shared types / signatures / tests likely affected

**Code tasks**
1. [Implementation sub-task]
2. [Implementation sub-task]

**Unit tests**
File: `src/lib/[module]/[file].test.ts`
| Function | Cases |
|---|---|
| `functionName` | nominal · edge · error |

**Component tests** *(if the task adds/changes UI — else `N/A`)*
File: `src/components/[Component].test.tsx`
| Component | States / interactions |
|---|---|
| `Component` | renders · empty · error · disabled · onAction fires · axe clean |

**Integration tests** *(if the task adds/changes an API route or DB access — else `N/A`)*
File: `tests/integration/[route].test.ts`
| Endpoint / flow | Cases (real test DB) |
|---|---|
| `POST /api/...` | persists + scoped to isolation key · validation error · soft-delete respected |

**E2E tests**
File: `tests/e2e/[feature].spec.ts`
| # | Initial state | Action | Assertion |
|---|---|---|---|
| 1 | [state] | [action] | [expected result] |

**UAT:** [What the user sees or does in the browser to verify this works]
**QA:** — (to be signed off)
**Delivery:** — *(filled by `/pr-reviewer`: Commit · PR · Started · Delivered · Cycle time — timestamps ISO 8601 UTC)*
```

---

## Global status

| Domain | Planned | In progress | Done |
|--------|---------|-------------|------|
| Visual baseline review (tooling) | 0 | 0 | 5 |
| Pipeline tooling | 1 | 0 | 0 |

---

## 🏃 Sprint 1 — Visual Baseline Review (opt-in)

An opt-in, tiered visual-regression capability for the pipeline, **disabled by default** to keep the
template stack-agnostic. Tier 1 = Playwright full-route screenshots; Tier 2 adds Storybook
component isolation; Tier 3 adds a clickable local review app. Human visual approval is the final,
**non-blocking** async gate before PR merge.

| Task | Status | Delivered |
|------|--------|-----------|
| VBR-1 Visual testing enablement + Tier 1 scaffolding | ✅ | 2026-07-03 |
| VBR-2 Agent guardrails + approval-state reader | ✅ | 2026-07-03 |
| VBR-3 Pipeline wiring (qa-tester · pr-reviewer · ship-task) | ✅ | 2026-07-03 |
| VBR-4 Tier 2 — Storybook component-isolation option | ✅ | 2026-07-03 |
| VBR-5 Tier 3 — custom local review app | ✅ | 2026-07-03 |

<!-- Add task blocks below using the template above -->

## 🏃 Sprint 2 — Pipeline scaling

| Task | Status | Delivered |
|------|--------|-----------|
| RB-1 Roadmap scaling: archive done tasks + selective reads | ⬜ | — |

### RB-1 — Roadmap scaling: archive done tasks + selective reads

**Sprint:** Sprint 2
**Write date:** 2026-07-03
**Planned date:** 2026-07-17
**Completion date:** —
**Type:** Feature
**Risk:** Medium *(archiving rewrites the roadmap structure many agents depend on — must be lossless + idempotent)*
**Priority:** P1
**Dependencies:** None

**Description**
Keep `docs/ROADMAP.md` proportional to *active work* rather than *cumulative history*. Today the file
is read (often in full) by nearly every agent — `/planner`, `/start-task`, `/ship-task` (validate +
batch), `/pr-reviewer`, `/roadmap-status` — so on a long-lived project it grows past thousands of
lines and taxes every run's tokens while making block extraction slow and error-prone. Two moves:
(1) an **archive** mode in `/roadmap-status` that sweeps completed `[x]` task blocks into
`docs/roadmap/archive/sprint-<N>.md` leaving a one-line ledger entry in the live file; (2) update the
**read-instructions** in the consuming agents so they read a slice (the one task block, or the
status/ledger tables) instead of the whole file. Git history preserves full blocks regardless.

**User value**
As a pipeline maintainer on a long-running project, I want the live roadmap to stay small and agents to
read only the slice they need, so that every agent run stays fast and cheap no matter how much work has
already shipped.

**Acceptance criteria**
- [ ] `/roadmap-status archive` moves every `[x]` task block out of `docs/ROADMAP.md` into `docs/roadmap/archive/sprint-<N>.md` (grouped by the task's sprint) and leaves a compact ledger row in the live file: `| <ID> | <title> | ✅ <date> | <PR> |`.
- [ ] **Lossless round-trip** — every archived block is written to the archive byte-for-byte (heading through last field); nothing is dropped or truncated; the archive file is valid markdown and readable on its own.
- [ ] **Idempotent** — re-running `archive` with no newly-done tasks makes no changes; running it twice never duplicates a block or a ledger row.
- [ ] After archiving, the live `docs/ROADMAP.md` contains only the static header (DoR/DoD/Template), active + planned task blocks, the sprint status tables, and the done-ledger — no full `[x]` blocks.
- [ ] The consuming agents' read-instructions are updated to read selectively: `/start-task` and `/ship-task` (validate) locate the single task block by ID (grep + offset/limit) rather than the whole file; `/ship-task` batch reads the status/ledger tables + only non-done blocks; `/pr-reviewer` reads the target block + status table; `/planner` reads the header + current sprint. The static DoR/DoD/Template header stays in `docs/ROADMAP.md`.
- [ ] **No-op safety** — on an empty roadmap or one with zero `[x]` tasks, `archive` reports "nothing to archive" and changes nothing; it never creates an empty archive file.
- [ ] The archive convention (location, ledger format, that git holds full history) is documented in `CLAUDE.md` and `.claude/context.md` (Generated files & artifacts).

**Schema impact:** None — documentation/tooling only, no data model.

**Components:** `.claude/skills/roadmap-status/SKILL.md` (new `archive` mode + `archive.mjs`) · `.claude/skills/start-task/SKILL.md` · `.claude/skills/ship-task/SKILL.md` · `.claude/skills/pr-reviewer/SKILL.md` · `.claude/skills/planner/SKILL.md` (read-instructions) · `docs/roadmap/archive/` (new) · `CLAUDE.md` · `.claude/context.md`

**API:** N/A — no HTTP routes.

**Change-set (locate):** *change-type — refine with `/locate` before coding.*
- Targets: the five skill files' roadmap-read steps · `roadmap-status/SKILL.md` gains the archive procedure · Call path: `/roadmap-status archive` → parse `[x]` blocks → append to archive → replace with ledger row → rewrite live file · Ripples: any doc describing the roadmap layout (CLAUDE.md two-tier table, context.md artifacts table); the ledger table shape the batch scan reads

**Code tasks**
1. Define the archive layout + ledger row format; create `docs/roadmap/archive/` with a short README.
2. Add the `archive` procedure to `/roadmap-status` (identify done blocks by Completion date, append losslessly, replace with ledger row, idempotent + no-op guards).
3. Update read-instructions in `/start-task`, `/ship-task`, `/pr-reviewer`, `/planner` to read selectively (single block by ID / tables / current sprint).
4. Document the archive convention in `CLAUDE.md` and `.claude/context.md`.

**Unit tests**
File: `.claude/skills/roadmap-status/tests/archive.test.mjs`
| Function | Cases |
|---|---|
| archive sweep | one delivered block → moved to archive + ledger row left · lossless (archived content equals original block) · mixed done/open → only done moved |
| idempotency | re-run with nothing new → zero changes · never duplicates a block/row |
| no-op | empty roadmap → "nothing to archive", no archive file created · zero delivered → no change |

**Component tests** *(N/A — no UI)*

**Integration tests** *(N/A — no API/DB; behaviour verified by the fixture tests above)*

**E2E tests**
File: manual scenario in `.claude/skills/roadmap-status/tests/README.md`
| # | Initial state | Action | Assertion |
|---|---|---|---|
| 1 | Roadmap with several delivered + open tasks | `/roadmap-status archive` | Live file keeps only active/planned + ledger; `docs/roadmap/archive/sprint-N.md` holds the full done blocks; re-run is a no-op |
| 2 | Long roadmap after archive | `/start-task <open-id>` | Locates the task block without reading the whole file |

**UAT:** Maintainer runs `/roadmap-status archive` on a bloated roadmap and sees the live file shrink to active work + a done-ledger, with the full history intact under `docs/roadmap/archive/`; a re-run reports nothing to archive.
**QA:** — (to be signed off)
**Delivery:** —

---

## ✅ Delivered (archived)

> Full task blocks live in `docs/roadmap/archive/` and in git history.

| ID | Title | Done | PR |
|----|-------|------|----|
| VBR-5 | Tier 3: custom local review app | ✅ 2026-07-03 | — |
| VBR-4 | Tier 2: Storybook component-isolation option | ✅ 2026-07-03 | — |
| VBR-3 | Pipeline wiring (qa-tester · pr-reviewer · ship-task) | ✅ 2026-07-03 | — |
| VBR-2 | Agent guardrails + approval-state reader | ✅ 2026-07-03 | — |
| VBR-1 | Visual testing enablement + Tier 1 scaffolding | ✅ 2026-07-03 | — |
