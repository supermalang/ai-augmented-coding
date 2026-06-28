# ROADMAP

*Dernière mise à jour : [DATE]*

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
- [ ] The **story map** is current — the user journey is mapped and every journey gap is either planned as a task or consciously deferred (`/story-map`)

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
| [Domain A] | 0 | 0 | 0 |
| [Domain B] | 0 | 0 | 0 |

---

## 🏃 Sprint 1 — [Title]

| Task | Status | Delivered |
|------|--------|-----------|
| [ID] [Title] | ⬜ | — |

<!-- Add task blocks below using the template above -->
