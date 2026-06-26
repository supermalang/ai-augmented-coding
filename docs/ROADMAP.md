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
- [ ] Unit tests written and passing (`test:coverage` above thresholds)
- [ ] E2E tests written and passing
- [ ] No lint errors (`npm run lint`)
- [ ] Code reviewed (security, performance, UX if applicable)
- [ ] Roadmap task marked `[x]` with completion date
- [ ] PR/MR opened and linked

---

## Task Template

Copy this block when creating a new task via `/planner`.

```markdown
### [ID] — [Short task title]

**Sprint:** Sprint N
**Write date:** YYYY-MM-DD
**Planned date:** YYYY-MM-DD
**Completion date:** —
**Risk:** Low | Medium | High
**Priority:** P0 | P1 | P2  *(P0 = must ship this sprint / blocking · P1 = important, not blocking · P2 = nice to have)*

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

**E2E tests**
File: `tests/e2e/[feature].spec.ts`
| # | Initial state | Action | Assertion |
|---|---|---|---|
| 1 | [state] | [action] | [expected result] |

**UAT:** [What the user sees or does in the browser to verify this works]
**QA:** — (to be signed off)
**Delivery:** —
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
