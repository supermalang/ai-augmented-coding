---
name: story-map
description: Story mapping and impact mapping — the product-planning views above the flat backlog. Story map lays the user journey left-to-right (backbone activities → steps) and stories top-to-bottom sliced by release, so you see the walking skeleton and what's in/out of each release. Reconciles the map against the roadmap bidirectionally via each task's Journey coordinate — flagging journey GAPS (step with no task) and ORPHANS (task with no valid step). Impact map links a goal to actors → impacts → deliverables. Reads PRODUCT.md, discovery briefs, and the roadmap; writes docs/story-map.md. Read-only on code. Use when the backlog is big enough that a flat list hides the shape of the product.
---

# /story-map — Story Mapping & Impact Mapping

Before starting, read `PRODUCT.md` (vision, personas, goals), the discovery briefs in
`docs/discovery/`, and `docs/ROADMAP.md`. The map is a **view onto** existing stories — it does not
invent new scope.

## Role

The flat roadmap answers "what are the tasks"; it hides "what's the user's journey, and what's the
*smallest end-to-end slice* that delivers value." Story mapping (Jeff Patton) restores that shape:
**activities** across the top (the user's high-level steps in order), **tasks/steps** beneath each, and
**stories** stacked under those, cut by horizontal **release slices** — the top slice being the walking
skeleton. Impact mapping keeps the work honest by tracing every deliverable back to a measurable goal.

## Permissions

✅ CAN read    : `PRODUCT.md`, `docs/discovery/*`, `docs/ROADMAP.md`, `.claude/context.md`
✅ CAN write   : `docs/story-map.md` (story map + optional impact map) · the index row in `PRODUCT.md`
✅ CAN run     : read-only git for context
❌ CANNOT      : create or modify roadmap tasks (that's `/planner`) — it maps what exists, flags gaps
❌ CANNOT      : touch source, tests, or schema

## Argument (optional)

```
/story-map                 # build/refresh the story map from PRODUCT.md + roadmap
/story-map impact          # also (or only) build the impact map
```

---

## Step-by-step

### 1 — Gather the journey and the stories

- From `PRODUCT.md` + discovery briefs: the **personas** and their end-to-end **journey** (the backbone).
- From `docs/ROADMAP.md`: every task/story, its sprint, priority, `[x]`/open status, and its
  **`Journey:` coordinate** (`<activity> / <step>`, or `N/A — <reason>` for non-journey work).

The `Journey:` field is the join key that makes the map **bidirectional** — a task declares where it
sits on the journey, so the map can be reconciled against the roadmap both ways (step 2b), not just
drawn as a one-way view.

### 2 — Build the story map

Lay it out as a grid (markdown tables — story maps are 2-D, so prose won't do):

```markdown
## Story map — <product / persona>

**Backbone (user activities, left → right):**
| Discover | Sign up | Configure | Do the core job | Review | Share |

**Steps & stories under each activity, sliced by release:**

### Release 1 — Walking skeleton (smallest end-to-end value)
| Activity | Story (roadmap ID) | Status |
|---|---|---|
| Sign up | 1.1 Email signup | [x] |
| Do the core job | 2.3 Create a record | open |

### Release 2 — …
| … | … | … |
```

Rules:
- The **top slice must be a thin, end-to-end thread** — a user can complete the whole journey, even if
  each step is minimal. Don't fully build one activity before the others exist.
- Place each roadmap task in the grid **by its `Journey:` coordinate** (not by guessing) — the field is
  the source of truth for where a task belongs.

### 2b — Reconcile coverage (bidirectional traceability)

This is the point of the `Journey:` field: check the map and the roadmap agree **both directions**, and
emit a traceability matrix. This is a **read-only reconciliation** — you report mismatches, you never
create or edit tasks (that stays `/planner`).

1. **Journey → roadmap (find GAPS).** For every step on the backbone, list the task(s) whose `Journey:`
   coordinate matches. A step with **no matching task** is a `⚠️ GAP — no roadmap task`.
2. **Roadmap → journey (find ORPHANS).** For every open/planned task, check its `Journey:` coordinate.
   A task whose coordinate **matches no step on the backbone** (a typo, a renamed step, or a step missing
   from the map) is a `⚠️ ORPHAN`; a task **missing the field entirely** and not marked `N/A` is
   `⚠️ UNMAPPED`. (Tasks correctly marked `N/A — <reason>` are expected — list them once under
   *Non-journey work*, not as errors.)

Write a coverage matrix into the map:

```markdown
## Traceability & coverage

| Backbone step | Task(s) | Status |
|---|---|---|
| Sign up / Email signup | 1.1 | [x] |
| Sign up / Verify email | — | ⚠️ GAP → /planner |
| Do the core job / Create record | 2.3 | open |

**Orphans / unmapped** (task → no matching step):
- 4.2 — Journey `Checkout / Refund` matches no backbone step (rename step or fix the coordinate)
- 5.7 — no `Journey:` field and not `N/A` → ⚠️ UNMAPPED

**Non-journey work (N/A, expected):** INF-3 (tooling) · RB-1 (roadmap archiver)

**Coverage:** <m>/<n> backbone steps have a task · <k> GAPS · <o> orphans/unmapped
```

Both lists are the actionable output: **GAPS** and **UNMAPPED/ORPHANS** go to `/planner` (create the
missing task, or fix/justify the coordinate on the existing one).

### 3 — (Optional) Impact map

```markdown
## Impact map — Goal: <measurable goal, e.g. "cut onboarding time 50%">
- **Actor:** <persona / system>
  - **Impact** (behaviour change we want): <e.g. "completes setup without support">
    - **Deliverable** (what we build): <story / roadmap ID>  ·  or  ⚠️ none yet
```

Read it as "to reach this **goal**, which **actors** must change behaviour (**impact**), and what
minimum **deliverables** cause that?" Deliverables with no goal, and goals with no deliverable, are both
flagged — they're the misalignments.

### 4 — Report back

```
✅ Story map → docs/story-map.md
🗺️  Releases  : <n> slices · <n> stories mapped
🔗 Coverage  : <m>/<n> backbone steps covered · <k> GAPS · <o> orphans/unmapped
🎯 Impact map : <built / skipped>
➡️  Next       : /planner to fill GAPS and fix orphan/unmapped Journey coordinates
```

---

## What story-map does NOT do

- Does not create or edit roadmap tasks — it maps existing ones and flags gaps for `/planner`.
- Does not invent scope beyond the vision in `PRODUCT.md`.
- Does not touch code, tests, or schema.
- Does not replace the roadmap — it's the journey/outcome view *above* it; the roadmap stays the
  source of truth for task detail and status.
